require "minitest/autorun"
require "nokogiri"
require "open3"
require "yaml"

class SiteAcceptanceTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  EXPECTED_ROUTES = %w[index.html research-agenda.html publications.html teaching.html].freeze
  EXPECTED_TAG_COUNTS = {
    "AI Behavior" => 4,
    "Social Computing" => 7,
    "AI4OceanScience" => 3,
    "AI4Geography" => 5,
    "Other" => 2
  }.freeze

  def data(name)
    YAML.safe_load_file(File.join(ROOT, "_data", "#{name}.yml"), aliases: true)
  end

  def test_expected_routes_and_shared_layout_exist
    EXPECTED_ROUTES.each do |route|
      assert_path_exists File.join(ROOT, route)
    end

    %w[_layouts/default.html _includes/header.html _includes/footer.html assets/css/main.css assets/js/site.js].each do |path|
      assert_path_exists File.join(ROOT, path)
    end
  end

  def test_profile_contains_all_public_contact_links
    profile = data("profile")

    assert_equal "Zheng Jiang", profile.fetch("name")
    assert_equal "蒋政", profile.fetch("chinese_name")
    assert_equal "nicezheng.jiang@gmail.com", profile.fetch("email")
    assert_equal "Ph.D. Candidate", profile.fetch("position")
    assert_equal %w[Google\ Scholar GitHub X LinkedIn CV], profile.fetch("social_links").map { |link| link.fetch("label") }
    profile.fetch("social_links").each { |link| refute_empty link.fetch("url") }
    assert_equal "/assets/files/Zheng_Jiang_CV.pdf", profile.fetch("social_links").last.fetch("url")
  end

  def test_all_resume_content_is_present
    assert_equal 11, data("activities").length
    assert_equal 2, data("education").length
    assert_equal 4, data("awards").length
    assert_path_exists File.join(ROOT, "_data", "services.yml")
    assert_equal 2, data("services").length
    assert_equal 4, data("teaching").length
    assert_equal 4, data("research").length
    assert_equal 17, data("publications").length
  end

  def test_publication_schema_links_and_filter_counts
    publications = data("publications")
    ids = publications.map { |publication| publication.fetch("id") }
    assert_equal ids.uniq, ids

    publications.each do |publication|
      %w[id title authors venue year tags].each { |key| refute_empty publication.fetch(key).to_s }
      publication.fetch("authors").each do |author|
        refute_empty author.fetch("name")
        assert_includes [true, false], author.fetch("self")
      end
      publication.fetch("links", []).each do |link|
        assert_match %r{\Ahttps://}, link.fetch("url"), "publication resources should use HTTPS"
        assert_includes %w[Paper Code Project\ Proposal Data], link.fetch("label")
      end

      next if publication.fetch("venue") == "Preprint"

      assert publication.key?("venue_url"), "formal venue should link to its official page: #{publication.fetch('id')}"
      assert_match %r{\Ahttps://}, publication.fetch("venue_url"), "venue links should use HTTPS"
    end

    EXPECTED_TAG_COUNTS.each do |tag, expected_count|
      actual_count = publications.count { |publication| publication.fetch("tags").include?(tag) }
      assert_equal expected_count, actual_count, "wrong count for #{tag}"
    end
  end

  def test_research_cards_reference_real_publications
    publication_ids = data("publications").map { |publication| publication.fetch("id") }

    data("research").each do |card|
      %w[id title accent paragraphs related_publication_ids].each { |key| refute_empty card.fetch(key).to_s }
      assert_operator card.fetch("paragraphs").length, :>=, 2
      card.fetch("related_publication_ids").each { |id| assert_includes publication_ids, id }
    end
  end

  def test_research_directions_render_the_selected_roadmaps_accessibly
    research = Nokogiri::HTML5(File.read(File.join(ROOT, "_site", "research-agenda.html"), encoding: "UTF-8"))
    expected_roadmaps = {
      "human-ai-decision-making" => "/assets/images/research-roadmaps/human-ai-open-source.png",
      "llm-values-ai-orientalism" => "/assets/images/research-roadmaps/geopolitical-bias-pluralistic-ai-v3.png",
      "ai-geography" => "/assets/images/research-roadmaps/ai-for-geography-v2.png",
      "ai-ocean-science" => "/assets/images/research-roadmaps/ai-for-ocean-science-v2.png"
    }

    assert_equal expected_roadmaps.keys, research.css("section.research-direction").map { |section| section["id"] }

    expected_roadmaps.each do |direction_id, image_path|
      direction = research.at_css("section##{direction_id}")
      figure = direction.at_css("figure.research-visual")
      image = figure&.at_css("img")
      link = figure&.at_css("a")

      refute_nil figure, "#{direction_id} should render its research roadmap"
      assert_equal image_path, image&.[]("src")
      assert_equal image_path, link&.[]("href")
      refute_empty image&.[]("alt").to_s
      assert_includes direction.at_css("h2")["class"].to_s.split, "visually-hidden"
    end
  end

  def test_editable_cv_source_and_linked_pdf_exist
    tex_path = File.join(ROOT, "cv-source", "Zheng_Jiang_CV.tex")
    pdf_path = File.join(ROOT, "assets", "files", "Zheng_Jiang_CV.pdf")
    assert_path_exists tex_path
    assert_path_exists File.join(ROOT, "cv-source", "LICENSE.md")
    assert_path_exists pdf_path

    tex = File.read(tex_path, encoding: "UTF-8")
    normalized_tex = tex
      .gsub("\\&", "&")
      .gsub("\\textsuperscript{2}", "²")
      .gsub("---", "—")
      .gsub("\\\\", "")
    assert_includes normalized_tex, "Zheng Jiang"
    assert_includes normalized_tex, "RESEARCH INTERESTS"
    assert_includes normalized_tex, "PUBLICATIONS"
    data("publications").each { |publication| assert_includes normalized_tex, publication.fetch("title") }
  end

  def test_cv_pdf_uses_two_page_letter_layout
    pdf_path = File.join(ROOT, "assets", "files", "Zheng_Jiang_CV.pdf")
    info, error, status = Open3.capture3("pdfinfo", pdf_path)

    assert status.success?, "pdfinfo failed: #{error}"
    assert_match(/^Pages:\s+2$/, info)
    assert_match(/^Page size:\s+612 x 792 pts \(letter\)$/, info)
  end

  def test_cv_pdf_contains_all_requested_sections
    pdf_path = File.join(ROOT, "assets", "files", "Zheng_Jiang_CV.pdf")
    text, error, status = Open3.capture3("pdftotext", "-layout", pdf_path, "-")
    text = text.force_encoding("UTF-8").scrub

    assert status.success?, "pdftotext failed: #{error}"
    %w[RESEARCH\ INTERESTS EDUCATION PUBLICATIONS HONORS\ AND\ AWARDS SERVICES TEACHING\ EXPERIENCE].each do |heading|
      assert_includes text, heading
    end
    assert_includes text, "Ph.D. Candidate"
    assert_includes text, "Phone: +86 156 7831 2406"
    assert_includes text, "Email: nicezheng.jiang@gmail.com"
    assert_includes text, "Website: nicezheng.github.io"
    assert_includes text, "LinkedIn"
    assert_includes text, "X"
    data("awards").each { |award| assert_includes text, award.fetch("title") }
    data("services").each { |service| assert_includes text, service.fetch("role") }
    data("teaching").each { |item| assert_includes text, item.fetch("course") }
    publication_numbers = text.scan(/^\s*(\d+)\.\s/).flatten.map(&:to_i)
    assert_equal (1..17).to_a, publication_numbers
    refute_includes text, "Program CommitteeAAAI"

    pages = text.split("\f").reject { |page| page.strip.empty? }
    assert_equal 2, pages.length
  end

  def test_cv_publications_use_full_venue_names_without_resource_links
    pdf_path = File.join(ROOT, "assets", "files", "Zheng_Jiang_CV.pdf")
    text, error, status = Open3.capture3("pdftotext", "-layout", pdf_path, "-")
    text = text.force_encoding("UTF-8").scrub.gsub(/\s+/, " ")

    assert status.success?, "pdftotext failed: #{error}"
    expected_venues = [
      "12th International Conference on Computational Social Science (IC2S2), 2026.",
      "Findings of the Association for Computational Linguistics (ACL Findings), 2026.",
      "35th International Joint Conference on Artificial Intelligence (IJCAI-ECAI), AI and Social Good Track, 2026.",
      "48th Annual Meeting of the Cognitive Science Society (CogSci), 2026.",
      "40th Annual AAAI Conference on Artificial Intelligence (AAAI), AI for Social Impact Track, 2026.",
      "IEEE/ACM International Conference on Software Engineering (ICSE), Future of Software Engineering Track, 2026.",
      "46th IEEE Symposium on Security and Privacy (S&P), 2025.",
      "28th European Conference on Artificial Intelligence (ECAI), Prestigious Applications of Intelligent Systems (PAIS), 2025.",
      "4th ACM International Conference on Information Technology for Social Good (GoodIT), 2024.",
      "27th European Conference on Artificial Intelligence (ECAI), 2024.",
      "38th AAAI Conference on Artificial Intelligence (AAAI), Innovative Applications of Artificial Intelligence (IAAI), 2024.",
      "46th Annual Meeting of the Cognitive Science Society (CogSci), 2024."
    ]
    expected_venues.each { |venue| assert_includes text, venue }
    refute_match(/\[(?:Paper|Code)\]/, text)

    urls, url_error, url_status = Open3.capture3("pdfinfo", "-url", pdf_path)
    assert url_status.success?, "pdfinfo -url failed: #{url_error}"
    data("publications").flat_map { |publication| publication.fetch("links") }.each do |link|
      refute_includes urls, link.fetch("url")
    end
    refute_includes urls, "https://aaai.org/conference/aaai/aaai-26/aisi-call/"
    refute_includes urls, "https://neurips.cc/Conferences/2026"
  end

  def test_cv_first_page_fills_before_the_natural_page_break
    pdf_path = File.join(ROOT, "assets", "files", "Zheng_Jiang_CV.pdf")
    bbox, error, status = Open3.capture3("pdftotext", "-bbox", pdf_path, "-")

    assert status.success?, "pdftotext -bbox failed: #{error}"
    document = Nokogiri::XML(bbox)
    first_page = document.at_xpath("//*[local-name()='page']")
    refute_nil first_page
    bottommost_text = first_page.xpath(".//*[local-name()='word']").map { |word| word["yMax"].to_f }.max
    assert_operator bottommost_text, :>, 650.0
  end

  def test_source_has_no_reference_author_or_placeholder_content
    source_paths = Dir.glob(File.join(ROOT, "{*.html,_includes/*.html,_layouts/*.html,_data/*.yml,assets/**/*.{css,js}}"))
    combined_source = source_paths.sort.map { |path| File.read(path, encoding: "UTF-8") }.join("\n")

    refute_match(/Hua Shen|BiAlign|huashen218|NYU Shanghai/, combined_source)
    refute_match(/href=["']#["']|\bXX\b/, combined_source)
  end

  def test_hover_text_color_meets_wcag_aa_contrast
    css = File.read(File.join(ROOT, "assets", "css", "main.css"), encoding: "UTF-8")
    surface = css[/--surface:\s*(#[0-9a-f]{6})/i, 1]
    hover_text = css[/--brand-color-hover-text:\s*(#[0-9a-f]{6})/i, 1]

    refute_nil surface
    refute_nil hover_text, "define a readable hover text color separately from the orange accent"
    assert_operator contrast_ratio(surface, hover_text), :>=, 4.5
  end

  def test_built_site_contains_navigation_and_accessible_controls
    EXPECTED_ROUTES.each do |route|
      assert_path_exists File.join(ROOT, "_site", route)
    end

    home = File.read(File.join(ROOT, "_site", "index.html"), encoding: "UTF-8")
    publications = File.read(File.join(ROOT, "_site", "publications.html"), encoding: "UTF-8")

    %w[About Research\ Agenda Publications Teaching].each { |label| assert_includes home, label }
    assert_includes home, 'aria-expanded="false"'
    assert_includes home, "Show all activities"
    assert_equal 17, publications.scan('class="publication-item"').length
    assert_equal 6, publications.scan('class="filter-button').length
    assert_includes publications, 'aria-live="polite"'

    home_document = Nokogiri::HTML5(home)
    activity_toggle = home_document.at_css("[data-activity-toggle]")
    activity_list = home_document.at_css("[data-activity-list]")
    refute_nil activity_list["id"], "activity list needs an id for aria-controls"
    assert_equal activity_list["id"], activity_toggle["aria-controls"]
  end

  def test_homepage_services_and_publication_venue_links_are_rendered
    home = Nokogiri::HTML5(File.read(File.join(ROOT, "_site", "index.html"), encoding: "UTF-8"))
    publications = Nokogiri::HTML5(File.read(File.join(ROOT, "_site", "publications.html"), encoding: "UTF-8"))

    assert_equal "Services", home.at_css("#services-heading")&.text&.strip
    assert_equal 2, home.css("li.service-item").length
    assert_includes home.text, "Program Committee"
    assert_includes home.text, "Reviewer"

    formal_venue_count = data("publications").count { |publication| publication.fetch("venue") != "Preprint" }
    assert_equal formal_venue_count, publications.css("a.publication-venue-link").length
    publications.css("a.publication-venue-link").each do |link|
      assert_equal "_blank", link["target"]
      assert_includes link["rel"].to_s.split, "noopener"
      assert_includes link["rel"].to_s.split, "noreferrer"
    end
  end

  def test_reference_style_uses_clean_headings_compact_lists_and_real_icons
    home = Nokogiri::HTML5(File.read(File.join(ROOT, "_site", "index.html"), encoding: "UTF-8"))
    research = Nokogiri::HTML5(File.read(File.join(ROOT, "_site", "research-agenda.html"), encoding: "UTF-8"))
    publications = Nokogiri::HTML5(File.read(File.join(ROOT, "_site", "publications.html"), encoding: "UTF-8"))
    teaching = Nokogiri::HTML5(File.read(File.join(ROOT, "_site", "teaching.html"), encoding: "UTF-8"))

    [research, publications, teaching].each do |document|
      assert_empty document.css(".eyebrow"), "inner pages should use the clean reference-site heading"
    end

    refute_includes publications.text, "Publications are listed in reverse chronological order."
    refute_includes teaching.text, "Teaching assistant experience at Beijing University of Posts and Telecommunications."
    refute_includes research.text, "My work connects social computing, human–AI decision-making, and AI for science through four complementary research directions."

    assert publications.at_css("ol.publication-list"), "publications should use the reference site's compact ordered-list structure"
    assert_empty publications.css(".publication-tags"), "publication categories belong only in the top filters"
    assert_empty publications.css(".publication-year"), "the reference layout keeps the year with the venue"
    assert_equal 17, publications.css("li.publication-item").length

    assert teaching.at_css("ul.teaching-list"), "teaching should use a compact semantic list"
    assert_equal 4, teaching.css("li.teaching-item").length
    assert_equal 4, research.css("section.research-direction").length
    assert_empty research.css(".research-card"), "research directions should not look like elevated cards"

    assert_empty home.css(".social-mark"), "letter badges should be replaced by the reference SVG icons"
    home.css(".social-link").each do |link|
      assert link.at_css("svg"), "each profile link should include an SVG icon"
    end
    assert home.at_css(".email-link svg"), "the email link should use the reference email icon"

    publications.css(".resource-link").each do |link|
      assert link.at_css("svg"), "publication resource links should include small reference-style icons"
    end

    assert_path_exists File.join(ROOT, "assets", "fonts", "NotoSerifSC-SemiBold.woff2")
    assert_path_exists File.join(ROOT, "assets", "fonts", "OFL.txt")
  end

  def test_unenhanced_html_keeps_all_content_visible
    home = Nokogiri::HTML5(File.read(File.join(ROOT, "_site", "index.html"), encoding: "UTF-8"))
    publications = Nokogiri::HTML5(File.read(File.join(ROOT, "_site", "publications.html"), encoding: "UTF-8"))

    assert_equal 11, home.css(".activity-item").length
    assert_empty home.css(".activity-item[hidden]")
    assert home.at_css("[data-activity-toggle][hidden]"), "activity toggle should start hidden without JavaScript"
    assert_equal 17, publications.css(".publication-item").length
    assert_empty publications.css(".publication-item[hidden]")
  end

  def test_built_internal_links_assets_fragments_and_external_link_safety
    built_pages = EXPECTED_ROUTES.map { |route| File.join(ROOT, "_site", route) }

    built_pages.each do |page_path|
      document = Nokogiri::HTML5(File.read(page_path, encoding: "UTF-8"))

      document.css("a[href]").each do |link|
        href = link["href"]
        if href.match?(%r{\Ahttps?://})
          assert_equal "_blank", link["target"], "external link should open safely: #{href}"
          rel = link["rel"].to_s.split
          assert_includes rel, "noopener", "missing noopener: #{href}"
          assert_includes rel, "noreferrer", "missing noreferrer: #{href}"
          next
        end
        next if href.start_with?("mailto:")

        path, fragment = href.split("#", 2)
        target_path = path.empty? ? page_path : built_target(path)
        assert_path_exists target_path, "missing internal target for #{href}"
        next if fragment.nil? || fragment.empty?

        target_document = Nokogiri::HTML5(File.read(target_path, encoding: "UTF-8"))
        assert target_document.at_css("##{fragment}"), "missing fragment target for #{href}"
      end

      document.css("img[src], script[src], link[href]").each do |asset|
        reference = asset["src"] || asset["href"]
        next if reference.match?(%r{\A(?:https?:)?//})

        assert_path_exists built_target(reference), "missing built asset for #{reference}"
      end
    end
  end

  private

  def contrast_ratio(first, second)
    lighter, darker = [relative_luminance(first), relative_luminance(second)].sort.reverse
    (lighter + 0.05) / (darker + 0.05)
  end

  def relative_luminance(hex)
    channels = hex.delete_prefix("#").scan(/../).map { |channel| channel.to_i(16) / 255.0 }
    converted = channels.map { |channel| channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4 }
    (0.2126 * converted[0]) + (0.7152 * converted[1]) + (0.0722 * converted[2])
  end

  def built_target(reference)
    path = reference.split(/[?#]/, 2).first.sub(%r{\A/}, "")
    if path.empty?
      path = "index.html"
    elsif reference.split(/[?#]/, 2).first.end_with?("/")
      path = File.join(path, "index.html")
    end
    File.join(ROOT, "_site", path)
  end
end
