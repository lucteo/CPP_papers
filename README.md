# CPP_papers
Source file for C++ standard papers

## Papers in this repo
- P3804. Rendered [R0 published](https://html-preview.github.io/?url=https://github.com/lucteo/CPP_papers/blob/main/generated/P3804.html) | [R1 (in progress)](https://html-preview.github.io/?url=https://github.com/lucteo/CPP_papers/blob/P3804R1/generated/P3804.html)
- P3609. Rendered [R0 (in progress)](https://html-preview.github.io/?url=https://github.com/lucteo/CPP_papers/blob/P3609R0/generated/P3609.html)
- P3481. Rendered: [latest published](https://html-preview.github.io/?url=https://github.com/lucteo/CPP_papers/blob/main/P3481.html)
- PXXX1 (abandoned). Rendered: [R1-in progress](https://html-preview.github.io/?url=https://github.com/lucteo/CPP_papers/blob/main/generated/PXXX1_abandoned.html)


## Other papers
- [P2079: System execution context](https://wg21.link/P2079) ([source](https://github.com/LeeHowes/CPP/blob/master/paper_framework_sources/p2079_system_execution_context.bs))
- [P3149: `async_scope` – Creating scopes for non-sequential concurrency](https://wg21.link/P3149)
- [P2300: `std::execution`](https://wg21.link/P2300) ([source](https://github.com/cplusplus/sender-receiver/blob/main/execution.bs))
- [P2504: Computations as a global solution to concurrency](https://wg21.link/P2504) ([source](https://github.com/lucteo/computations_solve_concurrency))

## Using

For continuously generate the paper as the source file is edited, run:
- `./serve.sh <paper_source_filename>`

This will open the paper in the browser, and will continuously regenerate it as the source changes.

### Papers using pandoc

Prerequisite:
- install `pandoc`; follow steps at [official documentation](https://pandoc.org/installing.html)

To generate the output file once:
- run `make -f wg21/Makefile <paper_name>.html
  - the paper with source at `<paper_name>.md` will be generated at `generated/<paper_name>.html`

### Papers using bikeshed

Prerequisite:
- install `pipx`; follow steps at [official documentation](https://pipx.pypa.io/latest/installation/#installing-pipx)

To generate the output file once:
- run `pipx run bikeshed spec <bikeshed_filename>`

To have live edits on the page:
- run `pipx run bikeshed serve <bikeshed_filename>`
- open [http://localhost:8000/](http://localhost:8000/) and open the corresponding .html file
- making changes to the source file will automatically regenerate the content; browser needs to be refreshed

