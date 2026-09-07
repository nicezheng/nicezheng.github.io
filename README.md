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

The website links to `assets/files/Zheng_Jiang_CV.pdf`. A future CV can replace
that PDF without changing the page templates.

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
```
