---
title: Linting notebooks with GitHub Actions
date: '2021-05-10 23:15:00'
layout: post
tags:
  - github-actions
  - super-linter
  - jupyter
  - ci-cd
---

Over the past year, [GitHub Actions](https://github.com/features/actions) has become my go-to tool for CI/CD for software projects, data projects, the source of [this blog](https://github.com/donaghhorgan/donaghhorgan.github.io), and even my CV! I've added workflows to many of my existing projects and include them by default whenever I'm creating new ones. In particular, the [Super-Linter](https://github.com/marketplace/actions/super-linter) action is extremely useful for ensuring correctness and consistency in committed code. Unfortunately though (at least as of the time I'm writing this) Jupyter notebooks aren't a supported format in Super-Linter - but luckily it's pretty straightforward to remedy this.

Most Super-Linter workflows look a bit like this:

```yaml
name: Lint code base

on: ...

jobs:
  lint:
    name: Lint code base
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v2

      ... # Custom tasks

      - name: Run Super-Linter
        uses: github/super-linter@v3
        env:
          DEFAULT_BRANCH: main
          GITHUB_TOKEN: {% raw %}${{ secrets.GITHUB_TOKEN }}{% endraw %}
```

Basically, you checkout your code, maybe run some custom tasks, and then lint your codebase.

Now, Jupyter notebooks aren't supported by Super-Linter directly - but Python and markdown source files are. If we convert each notebook in our repo to corresponding Python and markdown equivalents using [`nbconvert`](https://nbconvert.readthedocs.io/en/latest/index.html) prior to the linter running, then the newly created files will be linted and any issues in our notebooks should be flagged. For instance, if there's a Python issue in a notebook, then the same Python issue will appear in the converted source file. The same goes for markdown errors. Also, because the conversion is done during the workflow run, we're not committing any extra files to our repo - the converted Python and markdown files only exist in the context of the workflow run and will be deleted on completion.

To do the conversion, just add two custom steps to the workflow as follows:

```yaml
name: Lint code base

on: ...

jobs:
  lint:
    name: Lint code base
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v2

      - name: Convert notebooks to Python
        run: find . -type f -name "*.ipynb" -exec jupyter nbconvert --to python --TemplateExporter.exclude_markdown=true {} \;

      - name: Convert notebooks to Markdown
        run: find . -type f -name "*.ipynb" -exec jupyter nbconvert --to markdown --TemplateExporter.exclude_code_cell=true {} \;

      - name: Run Super-Linter
        uses: github/super-linter@v3
        env:
          DEFAULT_BRANCH: main
          GITHUB_TOKEN: {% raw %}${{ secrets.GITHUB_TOKEN }}{% endraw %}
```

Markdown is excluded when converting to Python and vice-versa so that the converted files are minimal to the language being linted. This way, there's no risk that the conversion of one format will cause a linting error in the other.

If you've got a Python or a markdown file with the same name as your notebook file and in the same directory, then you'll need to be a bit creative because `nbconvert` will overwrite the original if you use the code above directly - but shouldn't be too hard to modify this so that the converted files are placed in a subdirectory or are renamed to avoid overwrites.
