# Zheng Jiang Academic Homepage

This repository contains the source for Zheng Jiang's multi-page Jekyll
academic homepage.

## Local preview

```bash
bundle install
bundle exec jekyll serve
```

Open `http://127.0.0.1:4000/` in a browser.

## Updating content

Profile, activities, education, awards, research directions, publications, and
teaching entries live in `_data/`. The page templates render those files so
content only needs to be updated once.

Publications are grouped by publication status, not by link host. Entries with
`venue: Preprint` and self-hosted preprints appear in **Recent Preprints**; other
entries appear in **Selected Papers**. Keep manuscript resource labels as `Paper`
whether their URL points to SSRN, arXiv, a publisher, or a hosted PDF. `Code`
links keep their own label. Self-hosted titles are plain text and their resource
row shows only `Paper` and an optional `Code`, matching other publications.
Abstract pages and their citation metadata remain available at their existing URLs
and in the release sitemap, without separate `Abstract` links in Publications.
Numbering counts down continuously across both sections, from the total number
of papers to 1. Counts are calculated at build time, including hosted preprints;
no manual renumbering or JavaScript is needed when adding a paper.

The website links to `assets/files/Zheng_Jiang_CV.pdf`. A future CV can replace
that PDF without changing the page templates.

## What belongs in Git and on the public website

- **Tracked and published:** website pages and assets, the selected four research
  roadmaps, the public CV PDF, and released papers with their abstract pages and
  citation files. Jekyll uses tracked `_data`, `_includes`, and `_layouts` to build
  those pages; it does not serve those source directories directly.
- **Tracked for maintenance, not served:** `README.md`, `Gemfile`, `Gemfile.lock`,
  `scripts/`, `test/`, and the editable CV `.tex` source and license in `cv-source/`.
- **Local only:** `docs/` planning notes, `tstex_modules/`, `.DS_Store`, CV build
  intermediates and duplicate PDF, the retired filter configuration and five old
  roadmap images listed in `.gitignore`, preview snapshots, caches, and dependencies.
- **Private manuscript inputs:** keep ZIPs and LaTeX projects in `../paper-library/`,
  outside this repository. The Chinese resume remains outside this repository too.

`.gitignore` controls new Git additions; `_config.yml` exclusions control Jekyll
output. Both are needed because an ignored file can still exist in a local build,
and excluding a file from Jekyll does not hide it in a public GitHub repository.
Already tracked files must also be removed from the Git index with `git rm --cached`
to stop future uploads while preserving their local copies. This does not erase
copies from older commits.

The sitemap should contain the four public site pages plus released paper abstract
pages, never development notes. Acceptance tests check this boundary and confirm
that only the selected roadmap images are included in the build.

## Rebuilding the CV

The editable source is `cv-source/Zheng_Jiang_CV.tex`. With TeX Live and
XeLaTeX installed, rebuild the PDF from the project root:

```bash
mkdir -p tmp/pdfs
LC_ALL=en_US.UTF-8 latexmk -xelatex -outdir=tmp/pdfs cv-source/Zheng_Jiang_CV.tex
cp tmp/pdfs/Zheng_Jiang_CV.pdf assets/files/Zheng_Jiang_CV.pdf
```

The source template attribution and MIT license notice are preserved in
`cv-source/LICENSE.md`.

## Checks

```bash
ruby test/site_acceptance_test.rb
node --test test/site_js_test.mjs
bundle exec ruby test/paper_publishing_test.rb
```

## Self-hosted preprints: Google and Google Scholar

Keep each manuscript's private inputs **outside this repository**, for example
`../paper-library/healthcare-ai-governance/`. That folder contains `paper.pdf`,
`metadata.yml`, and optionally an original ZIP and LaTeX sources. Do not commit
that folder to any public repository. Jekyll's `exclude` does not make a file
private in a public GitHub repository.

The packaging command copies only an unchanged PDF and allowlisted publication
metadata. It never copies the ZIP, LaTeX, or private notes; never runs Git; and
does not infer a journal, DOI, or arXiv status from filenames.

### Preview, without releasing a paper

```bash
paper_preview=$(ruby scripts/paper.rb preview ../paper-library/healthcare-ai-governance)
bundle exec jekyll serve --source "$paper_preview" --destination "$paper_preview/_site" --host 127.0.0.1 --port 4001 --no-watch
```

Open `/papers/healthcare-ai-governance/` on port 4001. This snapshot uses `noindex`
without a visible preview notice; it assigns no first-publication date and does not
add the paper to the real repository. Recreate the snapshot after editing the
source site or private metadata. Stop the server with Ctrl-C first.

### Prepare the actual upload (only on the intended upload day)

```bash
ruby scripts/paper.rb release ../paper-library/healthcare-ai-governance
bundle exec jekyll build
bundle exec ruby test/site_acceptance_test.rb
bundle exec ruby test/paper_publishing_test.rb
git diff
git status --short
```

Review the output, then commit and push using your usual Git workflow. The
command itself **does not publish**. It creates:

```text
_data/hosted_papers/healthcare-ai-governance.yml
papers/healthcare-ai-governance/index.html
papers/healthcare-ai-governance/paper.pdf
papers/healthcare-ai-governance/citation.bib
```

The first `release` uses that day's date in Asia/Shanghai. If you postpone the
first upload, correct `publication_date` and `version_date` in the generated
YAML to the actual upload date before rerunning `release` (which regenerates
BibTeX). This is not a GitHub upload timestamp detector. Later releases preserve
the first-publication date; a changed PDF hash updates the version date. Normal
Jekyll rebuilds never change either date. For a postponed revised upload, correct
`version_date` before pushing too.

The paper is linked automatically from Publications. Citation tags contain one
author name per tag, without degrees or affiliation numbers; the visible author
line retains the PDF's display names. The full abstract is static HTML and the
absolute `citation_pdf_url` points to the PDF in the same directory. Do not
manually duplicate this entry in `_data/publications.yml`. The CV is not changed
automatically by publishing a manuscript.

The Publications list emphasizes the profile owner's name using the same bold,
underlined style as existing entries. The abstract page shows no BibTeX download
button; the optional generated citation file is retained, while Scholar uses the
HTML citation metadata rather than that download.

For a manuscript with a public code repository, add `code_url: https://...` to
its private `metadata.yml`. Packaging preserves this optional HTTPS link and
renders the same GitHub icon and `[Code]` label in Publications and on the abstract
page. Omit the field when no code link is available.

For local previews, `display_year: 2026` shows `Preprint, 2026` in Publications
without inventing a first-publication date or changing Scholar citation dates.
After release, the list uses the actual first-publication year instead.
Use `display_order: 1`, `2`, `3`, etc. to list hosted preprints newest first;
smaller numbers appear first, and entries without an order follow them.
Keep both optional fields in each manuscript's private `metadata.yml` so they
survive repackaging. The total countdown is still calculated automatically.

Corresponding-author details are not required or published on abstract pages.
An optional `rights_notice` in a manuscript's private `metadata.yml` displays
that exact, approved statement at the bottom of its abstract page. It does not
set the publication date or apply a license to other manuscripts.

### Search Console and indexing

1. Verify the URL-prefix property `https://nicezheng.github.io/` in Google Search
   Console. Put the supplied HTML-tag token into `google_site_verification` in
   `_config.yml`, or use Google's provided HTML verification file. No password
   or account credentials belong in the repository.
2. After deployment, submit `https://nicezheng.github.io/sitemap.xml` in Search
   Console and request indexing of the homepage and the new paper URL.
3. Check that the public abstract and PDF return HTTP 200 without login, and
   search Google Scholar by the complete paper title after it has had time to
   crawl. Search Console addresses Google Search, not a separate Scholar
   submission queue. Adding an entry to a Scholar profile is not evidence that
   the full text has been indexed.

Metadata improves eligibility and discovery; neither Google nor Scholar
guarantees inclusion or timing. An article DOI, arXiv ID, ORCID, or open license
is not required for this sample. Add them only when real and approved; a data
repository DOI is not an article DOI.

Official references: [Scholar inclusion](https://scholar.google.com/intl/en/scholar/inclusion.html),
[Search Console verification](https://support.google.com/webmasters/answer/9008080?hl=en),
[sitemap guidance](https://developers.google.com/search/docs/crawling-indexing/sitemaps/build-sitemap).
