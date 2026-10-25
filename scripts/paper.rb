#!/usr/bin/env ruby
# Packages approved, public-facing metadata and an unchanged PDF. Never runs Git.
require "yaml"
require "fileutils"
require "tmpdir"
require "digest"
require "date"
require "uri"
require "open3"
require "optparse"

module PaperPackage
  module_function

  def text(value, label)
    raise ArgumentError, "Missing #{label}" unless value.is_a?(String) && !value.strip.empty?
    value.strip
  end

  def metadata(folder)
    raw = YAML.safe_load_file(File.join(folder, "metadata.yml"))
    id = text(raw["id"], "id")
    raise ArgumentError, "Invalid id: use lowercase letters, digits and hyphens" unless id.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
    authors = raw.fetch("authors").map do |author|
      name = text(author["name"], "author name")
      { "name" => name, "display" => text(author["display"] || name, "author display"),
        "affiliations" => author["affiliations"].to_s }
    end
    raise ArgumentError, "At least one author is required" if authors.empty?
    data = {
      "id" => id, "title" => text(raw["title"], "title"), "authors" => authors,
      "affiliations" => raw.fetch("affiliations").map { |a| text(a, "affiliation") },
      "abstract" => text(raw["abstract"], "abstract"), "status" => "Preprint"
    }
    data["rights_notice"] = text(raw["rights_notice"], "rights notice") if raw["rights_notice"]
    if raw.key?("display_year")
      year = raw["display_year"]
      raise ArgumentError, "display_year must be a four-digit integer" unless year.is_a?(Integer) && year.between?(1000, 9999)
      data["display_year"] = year
    end
    if raw.key?("display_order")
      order = raw["display_order"]
      raise ArgumentError, "display_order must be a positive integer" unless order.is_a?(Integer) && order.positive?
      data["display_order"] = order
    end
    if raw["code_url"]
      code_url = text(raw["code_url"], "code URL")
      begin
        code_uri = URI.parse(code_url)
      rescue URI::InvalidURIError
        raise ArgumentError, "Code URL must be a valid HTTPS URL"
      end
      unless code_uri.is_a?(URI::HTTPS) && code_uri.host && !code_uri.host.empty? && !code_uri.userinfo
        raise ArgumentError, "Code URL must use HTTPS without embedded credentials"
      end
      data["code_url"] = code_url
    end
    data
  end

  def check_pdf(path)
    raise ArgumentError, "paper.pdf must be smaller than 5 MB" unless File.size(path).between?(1, 4_999_999)
    raise ArgumentError, "paper.pdf is not a PDF" unless File.binread(path, 5) == "%PDF-"
    content, error, status = Open3.capture3("pdftotext", "-enc", "UTF-8", path, "-")
    content = content.force_encoding(Encoding::UTF_8).scrub
    raise ArgumentError, "PDF must have extractable text: #{error}" unless status.success? && !content.strip.empty?
  end

  def bib_escape(value)
    replacements = { "\\" => "\\textbackslash{}", "{" => "\\{", "}" => "\\}",
      "&" => "\\&", "%" => "\\%", "$" => "\\$", "#" => "\\#", "_" => "\\_",
      "~" => "\\textasciitilde{}", "^" => "\\textasciicircum{}" }
    value.gsub(/[\\{}&%$#_~^]/) { |character| replacements.fetch(character) }
  end

  def bibtex(data, url)
    fields = {
      "title" => "{#{bib_escape(data.fetch('title'))}}",
      "author" => data.fetch("authors").map { |author| bib_escape(author.fetch("name")) }.join(" and "),
      "note" => "Preprint", "url" => url
    }
    fields["year"] = data["publication_date"][0, 4] if data["publication_date"]
    "@misc{#{data.fetch('id')},\n" + fields.map { |key, value| "  #{key} = {#{value}}" }.join(",\n") + "\n}\n"
  end

  def run(mode, folder, site)
    raise ArgumentError, "Use preview or release" unless %w[preview release].include?(mode)
    folder, site = File.realpath(folder), File.realpath(site)
    raise ArgumentError, "Private input must be outside the website repository" if folder == site || folder.start_with?(site + File::SEPARATOR)
    data = metadata(folder)
    pdf = File.join(folder, "paper.pdf")
    check_pdf(pdf)
    config = YAML.safe_load_file(File.join(site, "_config.yml"))
    origin = URI.parse(config.fetch("url"))
    raise ArgumentError, "Site URL must be an HTTPS origin" unless origin.is_a?(URI::HTTPS) && origin.host && !origin.userinfo && ["", "/"].include?(origin.path) && !origin.query && !origin.fragment
    baseurl = config.fetch("baseurl", "").to_s
    raise ArgumentError, "Invalid baseurl" unless baseurl.empty? || baseurl.match?(%r{\A/[a-zA-Z0-9_/-]+\z})
    slug = data.fetch("id")
    url = "#{config.fetch('url').delete_suffix('/')}#{baseurl.delete_suffix('/')}/papers/#{slug}/"
    metadata_path = File.join(site, "_data/hosted_papers", "#{slug}.yml")
    paper_directory = File.join(site, "papers", slug)
    previous = File.file?(metadata_path) ? YAML.safe_load_file(metadata_path) : nil
    managed = previous && previous["managed_by"] == "paper.rb" && previous["id"] == slug
    if (File.exist?(paper_directory) || File.exist?(metadata_path)) && !managed
      raise ArgumentError, "Refusing to overwrite an existing unmanaged paper: #{slug}"
    end
    digest = Digest::SHA256.file(pdf).hexdigest
    today = Time.now.getlocal("+08:00").strftime("%Y-%m-%d")
    date = previous && previous["publication_date"]
    if mode == "release"
      data["publication_date"] = date || today
      data["version_date"] = previous && previous["pdf_sha256"] == digest ? previous["version_date"] : today
    else
      data["publication_date"] = date
      data["version_date"] = previous && previous["version_date"]
    end
    data.merge!("preview" => mode == "preview", "pdf_sha256" => digest, "managed_by" => "paper.rb")

    # Only the preview snapshot contains an undated draft; the real repository does not.
    if mode == "preview"
      scratch = File.join(site, "tmp/paper-previews")
      FileUtils.mkdir_p(scratch)
      target = Dir.mktmpdir("preview-", scratch)
      excluded = %w[tmp vendor cv-source test scripts]
      Dir.children(site).reject { |entry| entry.start_with?(".") || entry == "_site" || excluded.include?(entry) }.each do |entry|
        FileUtils.cp_r(File.join(site, entry), target)
      end
    else
      target = site
    end
    output = File.join(target, "papers", slug)
    FileUtils.mkdir_p([output, File.join(target, "_data/hosted_papers")])
    File.write(File.join(target, "_data/hosted_papers", "#{slug}.yml"), YAML.dump(data))
    page = { "layout" => "paper", "paper_id" => slug, "title" => data.fetch("title"),
      "description" => data.fetch("abstract"), "permalink" => "/papers/#{slug}/",
      "page_class" => "paper", "noindex" => mode == "preview" }
    File.write(File.join(output, "index.html"), YAML.dump(page) + "---\n")
    FileUtils.cp(pdf, File.join(output, "paper.pdf"))
    File.write(File.join(output, "citation.bib"), bibtex(data, url))
    warn(mode == "preview" ? "Local preview only; no publication date assigned and no Git operations performed." : "Prepared for upload on #{today}; no Git operations performed. Push on this date, or correct the date before a delayed first upload.")
    puts target
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    options = { site: File.expand_path("..", __dir__) }
    parser = OptionParser.new do |opts|
      opts.banner = "Usage: ruby scripts/paper.rb preview|release PRIVATE_PAPER_FOLDER [--site SITE_ROOT]"
      opts.on("--site PATH") { |path| options[:site] = path }
    end
    parser.parse!
    raise ArgumentError, parser.to_s unless ARGV.length == 2
    PaperPackage.run(ARGV[0], ARGV[1], options[:site])
  rescue ArgumentError, KeyError, TypeError, Psych::Exception, SystemCallError => error
    warn "Paper packaging failed: #{error.message}"
    exit 1
  end
end
