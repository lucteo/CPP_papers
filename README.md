# CPP_papers
Source file for C++ standard papers

## Papers in this repo
- P3481. Rendered: [latest published](https://html-preview.github.io/?url=https://github.com/lucteo/CPP_papers/blob/main/P3481.html)
- P3609. Rendered: [R1-in progress](https://html-preview.github.io/?url=https://github.com/lucteo/CPP_papers/blob/P3609R0/generated/P3609.html)


## Other papers
- [P2079: System execution context](https://wg21.link/P2079) ([source](https://github.com/LeeHowes/CPP/blob/master/paper_framework_sources/p2079_system_execution_context.bs))
- [P3149: `async_scope` – Creating scopes for non-sequential concurrency](https://wg21.link/P3149)
- [P2300: `std::execution`](https://wg21.link/P2300) ([source](https://github.com/cplusplus/sender-receiver/blob/main/execution.bs))
- [P2504: Computations as a global solution to concurrency](https://wg21.link/P2504) ([source](https://github.com/lucteo/computations_solve_concurrency))

## Using

Prerequisite:
- install `pipx`; follow setps at [official documentation](https://pipx.pypa.io/latest/installation/#installing-pipx)

To generate the output file once:
- run `pipx run bikeshed spec <bikeshed_filename>`

To have live edits on the page:
- run `pipx run bikeshed serve <bikeshed_filename>`
- open [http://localhost:8000/](http://localhost:8000/) and open the corresponding .html file
- making changes to the source file will automatically regenerate the content; browser needs to be refreshed

