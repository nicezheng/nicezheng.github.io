# Research Narrative, CV, and Website Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Synchronize the approved research narrative and labeled contact information across the website and two-page English CV.

**Architecture:** Keep personal and research copy in the existing Jekyll `_data` files and render it through the current templates. Keep the PDF as an editable XeLaTeX source, then compile and visually inspect the generated two-page Letter artifact.

**Tech Stack:** Jekyll, YAML, Liquid, Ruby/Minitest, XeLaTeX, Poppler.

**Spec:** `docs/superpowers/specs/2026-09-11-research-narrative-cv-website.md`

## Global Constraints

- Use the four confirmed research direction titles verbatim.
- Do not use `unverifiable` or `alignment` as a research direction label.
- Preserve all 17 publication facts, authors, venue names, and order.
- Preserve the existing website visual design and two-page Letter CV format.
- Do not add a roadmap graphic, commit, or push.

---

### Task 1: Add the CV contact-output regression check

**Files:**
- Modify: `test/site_acceptance_test.rb`

**Interfaces:**
- Consumes: the compiled `assets/files/Zheng_Jiang_CV.pdf`.
- Produces: an acceptance check for labeled contact fields and required profile links in extracted PDF text.

- [ ] **Step 1: Write the failing test**

Extend `test_cv_pdf_contains_all_requested_sections` with literal assertions for
`Phone: +86 156 7831 2406`, `Email: nicezheng.jiang@gmail.com`,
`Website: nicezheng.github.io`, `LinkedIn`, and `X`.

- [ ] **Step 2: Run the targeted test and verify RED**

Run:

```bash
bundle exec ruby -Itest test/site_acceptance_test.rb --name test_cv_pdf_contains_all_requested_sections
```

Expected: failure because the current PDF does not contain the labeled phone,
email, and website fields.

### Task 2: Synchronize the website research identity

**Files:**
- Modify: `_data/profile.yml`
- Modify: `_data/research.yml`
- Modify: `_config.yml`
- Modify: `research-agenda.html`

**Interfaces:**
- Consumes: the confirmed four-direction terminology and website prose in the spec.
- Produces: Jekyll data and metadata rendered by the existing homepage and Research Agenda templates.

- [ ] **Step 1: Update the profile data**

Set the displayed role to `Ph.D. Candidate`, organize the biography around AI
in social systems and AI for science, and retain all existing personal links.

- [ ] **Step 2: Replace the four Research Agenda entries**

Use the confirmed titles and plain-language paragraphs. Keep each existing
`id`, `accent`, and `related_publication_ids` value unchanged.

- [ ] **Step 3: Update stale metadata**

Replace superseded `human-AI decision-making`, `LLM values`, and related summary
phrases in `_config.yml` and `research-agenda.html` with the confirmed program.

- [ ] **Step 4: Build the website**

Run:

```bash
bundle exec jekyll build
```

Expected: exit 0 with refreshed `_site` pages.

### Task 3: Update and compile the two-page CV

**Files:**
- Modify: `cv-source/Zheng_Jiang_CV.tex`
- Modify: `cv-source/Zheng_Jiang_CV.pdf` (generated)
- Modify: `assets/files/Zheng_Jiang_CV.pdf` (generated copy)

**Interfaces:**
- Consumes: labeled contact data and the four approved CV research-interest lines.
- Produces: the downloadable two-page Letter PDF.

- [ ] **Step 1: Update the contact header**

Use two compact lines. The first contains labeled phone, email, and website
links. The second contains Google Scholar, GitHub, LinkedIn, and X links.

- [ ] **Step 2: Replace the Research Interests introduction and bullets**

Use the two-theme overview and four approved direction titles. Keep each bullet
to one concise research-program sentence.

- [ ] **Step 3: Compile with XeLaTeX**

Run the bundled LaTeX compilation wrapper with the TeX Live XeLaTeX engine.

- [ ] **Step 4: Copy the compiled PDF to the stable website path**

Copy `cv-source/Zheng_Jiang_CV.pdf` to
`assets/files/Zheng_Jiang_CV.pdf` without changing the public URL.

- [ ] **Step 5: Run the targeted test and verify GREEN**

Run the targeted CV test from Task 1 and require zero failures.

### Task 4: Full verification and visual QA

**Files:**
- Verify: `_site/index.html`
- Verify: `_site/research-agenda.html`
- Verify: `assets/files/Zheng_Jiang_CV.pdf`

**Interfaces:**
- Consumes: the built Jekyll site and final PDF.
- Produces: fresh evidence that the website and CV satisfy the specification.

- [ ] **Step 1: Run the full Ruby acceptance suite**

```bash
bundle exec ruby -Itest test/site_acceptance_test.rb
```

- [ ] **Step 2: Run the JavaScript behavior suite**

```bash
node --test test/site_js_test.mjs
```

- [ ] **Step 3: Inspect PDF metadata and text**

Use `pdfinfo` and `pdftotext -layout` to confirm two Letter pages, all 17
numbered publications, labeled contact information, four research titles, and
all required sections.

- [ ] **Step 4: Render and inspect both PDF pages**

Render at high resolution with `pdftoppm -png` and inspect both pages for
clipping, overlap, inconsistent spacing, and weak page filling.

- [ ] **Step 5: Review the final diff**

Confirm no roadmap graphic, publication-fact change, commit, or push entered the
scope.
