require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"
require "yaml"
require "nokogiri"
require "date"
require "digest"

class PaperPublishingTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(ROOT, "scripts/paper.rb")

  def setup
    @tmp = File.realpath(Dir.mktmpdir("paper-publishing-test-"))
    @repo = File.join(@tmp, "site")
    @input = File.join(@tmp, "private")
    FileUtils.mkdir_p([@repo, @input])
    %w[_config.yml _layouts _includes _data assets cv-source test index.html publications.html research-agenda.html teaching.html robots.txt sitemap.xml].each do |entry|
      path = File.join(ROOT, entry)
      FileUtils.cp_r(path, @repo) if File.exist?(path)
    end
    @metadata = {
      "id" => "sample-paper", "title" => 'AI & Society: "Whose Values?"',
      "authors" => [{ "name" => "First Author", "display" => "First Author, PhD", "affiliations" => "1" }, { "name" => "Second Author", "display" => "Second Author", "affiliations" => "1*" }],
      "affiliations" => ["University & Institute"],
      "corresponding_author" => { "name" => "Second Author", "email" => "author@example.org" },
      "abstract" => 'A complete summary with "quotes" & comparisons: a < b.',
      "private_notes" => "DO NOT PUBLISH THIS NOTE",
      "doi" => "NOT AN ARTICLE DOI"
    }
    write_input
    FileUtils.cp(File.join(ROOT, "assets/files/Zheng_Jiang_CV.pdf"), File.join(@input, "paper.pdf"))
    File.write(File.join(@input, "original.zip"), "PRIVATE ZIP")
    File.write(File.join(@input, "main.tex"), "PRIVATE LATEX")
  end

  def teardown
    FileUtils.remove_entry(@tmp)
  end

  def write_input
    File.write(File.join(@input, "metadata.yml"), YAML.dump(@metadata))
  end

  def package(mode)
    assert_path_exists SCRIPT, "paper packaging command has not been implemented"
    out, err, status = Open3.capture3(RbConfig.ruby, SCRIPT, mode, @input, "--site", @repo)
    [out, err, status]
  end

  def run_package(mode)
    out, err, status = package(mode)
    assert status.success?, "#{mode} failed: #{err}#{out}"
    out.lines.last.strip
  end

  def build(source, baseurl: "", target: File.join(@tmp, "build-#{rand(1_000_000)}"))
    out, err, status = Open3.capture3("bundle", "exec", "jekyll", "build", "--source", source, "--destination", target, "--baseurl", baseurl, chdir: ROOT)
    assert status.success?, "Jekyll build failed: #{err}#{out}"
    target
  end

  def html(path)
    Nokogiri::HTML5(File.read(path, encoding: "UTF-8"))
  end

  def test_preview_has_complete_abstract_and_pdf_without_release_date_or_repository_writes
    source = run_package("preview")
    refute_path_exists File.join(@repo, "papers/sample-paper")
    output = build(source)
    page = html(File.join(output, "papers/sample-paper/index.html"))
    assert_equal @metadata["title"], page.at_css("h1").text.strip
    assert_equal @metadata["abstract"], page.at_css(".paper-abstract p").text.strip
    assert_equal "noindex, nofollow", page.at_css('meta[name="robots"]')["content"]
    assert_nil page.at_css('meta[name="citation_publication_date"]')
    refute_includes page.at_css("main").text, "Local preview"
    refute_includes page.at_css("main").text, "Not yet released"
    assert_empty page.css('a[href$="citation.bib"]')
    refute_includes page.at_css("main").text, "Corresponding author:"
    assert_empty page.css('.paper-detail a[href^="mailto:"]')
    assert_empty page.css('[data-paper-code]'), "omit Code when no code URL was supplied"
    assert_empty page.css(".paper-rights"), "do not invent a copyright statement for other manuscripts"
    assert_equal File.binread(File.join(@input, "paper.pdf")), File.binread(File.join(output, "papers/sample-paper/paper.pdf"))
    assert_empty Dir.glob(File.join(output, "**/*.{zip,tex}"))
    refute_includes File.read(File.join(source, "_data/hosted_papers/sample-paper.yml")), "DO NOT PUBLISH"
    refute_includes File.read(File.join(output, "sitemap.xml")), "sample-paper"
  end

  def test_release_emits_ordered_scholar_metadata_and_static_links_with_baseurl
    run_package("release")
    output = build(@repo, baseurl: "/demo")
    page = html(File.join(output, "papers/sample-paper/index.html"))
    assert_equal @metadata["title"], page.at_css('meta[name="citation_title"]')["content"]
    assert_equal ["First Author", "Second Author"], page.css('meta[name="citation_author"]').map { |n| n["content"] }
    assert_includes page.at_css(".paper-authors").text, "First Author, PhD"
    today = Time.now.getlocal("+08:00").strftime("%Y/%m/%d")
    assert_equal today, page.at_css('meta[name="citation_publication_date"]')["content"]
    assert_equal "https://nicezheng.github.io/demo/papers/sample-paper/paper.pdf", page.at_css('meta[name="citation_pdf_url"]')["content"]
    assert_equal "https://nicezheng.github.io/demo/papers/sample-paper/", page.at_css('link[rel="canonical"]')["href"]
    assert_equal "/demo/papers/sample-paper/paper.pdf", page.at_css('a[data-paper-pdf]')["href"]
    assert_nil page.at_css('meta[name="robots"]')
    assert_empty page.css('a[href$="citation.bib"]')
    assert_empty page.css('meta[name="citation_doi"], meta[name="citation_journal_title"], meta[name="citation_conference_title"]')
    pubs = html(File.join(output, "publications.html"))
    assert pubs.at_css("#recent-preprints #sample-paper"), "self-hosted preprints must appear in Recent Preprints"
    assert_nil pubs.at_css("#selected-papers #sample-paper")
    assert_equal "18", pubs.at_css("#recent-preprints ol")["start"], "adding a hosted preprint must increase the total automatically"
    assert_equal "14", pubs.at_css("#selected-papers ol")["start"], "selected papers must continue the same countdown"
    assert_equal @metadata["title"], pubs.at_css("#sample-paper h3").text.strip
    assert_empty pubs.css("#sample-paper h3 a"), "hosted paper titles should be plain text like other publications"
    assert_equal ["[Paper]"], pubs.css("#sample-paper .resource-link").map { |link| link.text.strip }, "show the PDF directly without a separate Abstract link"
    paper_link = pubs.css('#sample-paper .resource-link').find { |link| link.text.strip == "[Paper]" }
    refute_nil paper_link, "hosted manuscripts should use the same Paper label as other publications"
    assert_equal "/demo/papers/sample-paper/paper.pdf", paper_link["href"]
    map = Nokogiri::XML(File.read(File.join(output, "sitemap.xml"))) { |config| config.strict }
    assert_includes map.css("loc").map(&:text), "https://nicezheng.github.io/demo/papers/sample-paper/"
    refute_includes File.read(File.join(output, "sitemap.xml")), "citation.bib"
    assert_includes File.read(File.join(output, "robots.txt")), "Sitemap: https://nicezheng.github.io/demo/sitemap.xml"
    bib = File.read(File.join(output, "papers/sample-paper/citation.bib"))
    assert_includes bib, "First Author and Second Author"
    assert_includes bib, 'AI \\& Society'
    refute_includes bib, "arXiv"
    assert_empty Dir.glob(File.join(output, "**/*.{zip,tex}"))
  end

  def test_optional_code_url_is_preserved_and_rendered_with_github_icon
    @metadata["code_url"] = "https://github.com/example/research-code"
    write_input
    source = run_package("preview")
    data = YAML.safe_load_file(File.join(source, "_data/hosted_papers/sample-paper.yml"))
    assert_equal @metadata["code_url"], data["code_url"]
    output = build(source, baseurl: "/demo")
    publications = html(File.join(output, "publications.html"))
    assert_empty publications.css("#sample-paper h3 a")
    assert_equal ["[Paper]", "[Code]"], publications.css("#sample-paper .resource-link").map { |link| link.text.strip }
    code_link = publications.css("#sample-paper .resource-link").find { |link| link.text.strip == "[Code]" }
    detail_link = html(File.join(output, "papers/sample-paper/index.html")).at_css("[data-paper-code]")
    [code_link, detail_link].each do |link|
      refute_nil link, "Code should be available in Publications and the abstract page"
      assert_equal @metadata["code_url"], link["href"]
      assert_equal "_blank", link["target"]
      assert_includes link["rel"].split, "noopener"
      assert_includes link["rel"].split, "noreferrer"
      refute_nil link.at_css("svg")
    end
  end

  def test_preview_displays_supplied_year_without_assigning_a_publication_date
    @metadata["display_year"] = 2026
    write_input
    source = run_package("preview")
    output = build(source)
    publications = html(File.join(output, "publications.html"))
    assert_equal "Preprint, 2026", publications.at_css("#sample-paper .publication-venue").text.strip
    data = YAML.safe_load_file(File.join(source, "_data/hosted_papers/sample-paper.yml"))
    assert_nil data["publication_date"]
    assert_nil data["version_date"]
    page = html(File.join(output, "papers/sample-paper/index.html"))
    assert_nil page.at_css('meta[name="citation_publication_date"]')
  end

  def test_hosted_preprints_follow_explicit_recency_order_not_alphabetical_ids
    [["a-middle", 2], ["m-oldest", 3], ["z-newest", 1]].each do |id, order|
      @metadata["id"] = id
      @metadata["display_order"] = order
      write_input
      run_package("release")
    end
    publications = html(File.join(build(@repo), "publications.html"))
    assert_equal %w[z-newest a-middle m-oldest], publications.css(".hosted-paper").map { |row| row["id"] }
    assert_equal "20", publications.at_css("#recent-preprints ol")["start"]
    assert_equal "14", publications.at_css("#selected-papers ol")["start"]
  end

  def test_rejects_invalid_display_year_or_order_before_packaging
    [["display_year", 26], ["display_year", "2026-10-25"], ["display_order", 0], ["display_order", "first"]].each do |field, value|
      @metadata.delete("display_year")
      @metadata.delete("display_order")
      @metadata[field] = value
      write_input
      out, err, status = package("preview")
      refute status.success?, "should reject #{field}: #{value.inspect}"
      assert_includes out + err, field
    end
  end

  def test_rejects_unsafe_code_urls_before_packaging
    ["javascript:alert(1)", "http://github.com/example/repo", "https://user:password@github.com/example/repo", "not a URL"].each do |url|
      @metadata["code_url"] = url
      write_input
      out, err, status = package("preview")
      refute status.success?, "should reject unsafe code URL: #{url}"
      assert_match(/code|HTTPS/i, out + err)
    end
  end

  def test_repeat_release_preserves_first_publication_and_version_date_when_pdf_unchanged
    run_package("release")
    path = File.join(@repo, "_data/hosted_papers/sample-paper.yml")
    data = YAML.safe_load_file(path)
    data["publication_date"] = "2026-01-02"
    data["version_date"] = "2026-01-02"
    File.write(path, YAML.dump(data))
    run_package("release")
    data = YAML.safe_load_file(path)
    assert_equal "2026-01-02", data["publication_date"]
    assert_equal "2026-01-02", data["version_date"]
    File.open(File.join(@input, "paper.pdf"), "ab") { |file| file.write("\n% Updated PDF version\n") }
    run_package("release")
    data = YAML.safe_load_file(path)
    assert_equal "2026-01-02", data["publication_date"]
    assert_equal Time.now.getlocal("+08:00").strftime("%Y-%m-%d"), data["version_date"]
  end

  def test_hosted_publication_emphasizes_only_the_profile_author_like_existing_entries
    @metadata["authors"].insert(1, { "name" => "Zheng Jiang", "display" => "Zheng Jiang, PhD", "affiliations" => "1" })
    write_input
    output = build(run_package("preview"))
    pubs = html(File.join(output, "publications.html"))
    row = pubs.at_css("#sample-paper .publication-authors")
    assert_equal ["Zheng Jiang"], row.css("strong.self-author").map(&:text)
    assert_equal "First Author, Zheng Jiang, Second Author", row.text.strip
    assert_equal 1, row.css("strong").length
    refute_empty pubs.css(".publication-item:not(.hosted-paper) strong.self-author")
  end

  def test_displays_the_approved_per_paper_copyright_notice
    @metadata["rights_notice"] = "© 2026 The authors. All rights reserved."
    write_input
    output = build(run_package("preview"))
    page = html(File.join(output, "papers/sample-paper/index.html"))
    assert_equal ["© 2026 The authors. All rights reserved."], page.css(".paper-rights").map { |node| node.text.strip }
    assert_nil page.at_css('meta[name="citation_publication_date"]'), "a copyright year is not a publication date"
  end

  def test_paper_packaging_does_not_require_or_publish_correspondence
    @metadata.delete("corresponding_author")
    write_input
    source = run_package("preview")
    data = YAML.safe_load_file(File.join(source, "_data/hosted_papers/sample-paper.yml"))
    refute data.key?("corresponding_author")
    assert_equal "AI & Society: \"Whose Values?\"", data.fetch("title")
  end

  def test_rejects_unsafe_slug_before_any_output
    @metadata["id"] = "../escape"
    write_input
    out, err, status = package("release")
    refute status.success?
    assert_match(/id|slug/i, out + err)
    refute_path_exists File.join(@repo, "papers")
  end

  def test_does_not_overwrite_unmanaged_destination
    FileUtils.mkdir_p(File.join(@repo, "papers/sample-paper"))
    existing = File.join(@repo, "papers/sample-paper/index.html")
    File.write(existing, "USER PAGE")
    out, err, status = package("release")
    refute status.success?
    assert_match(/existing|managed/i, out + err)
    assert_equal "USER PAGE", File.read(existing)
  end

  def test_release_is_compatible_with_existing_site_acceptance_checks
    run_package("release")
    build(@repo, target: File.join(@repo, "_site"))
    out, err, status = Open3.capture3("bundle", "exec", "ruby", File.join(@repo, "test/site_acceptance_test.rb"), chdir: ROOT)
    assert status.success?, "Existing site acceptance checks failed after release: #{out}#{err}"
  end
end
