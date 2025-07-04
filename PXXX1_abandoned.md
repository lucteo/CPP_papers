---
title: On scheduler affinity in `std::lazy` -- abandoned
document: PXXX1R0
date: today
author:
    - name: Lucian Radu Teodorescu (Garmin)
      email: <lucteo@lucteo.ro>
audience:
    - LEWG
---

<style>
@media screen {
    #TOC {
        position: fixed;
        width: min(25%, 30em);
        height: 100%;
        left: 0;
        top: 0;
        overflow-y: scroll;
        padding-left: 1em;
        padding-right: 1em;
        text-align: left;
        a {
            font-size: 100%;
        }
    }
    body {
        padding-left: min(26%, 32em);
    }
}
</style>

# Abstract # {- .unlisted}

This paper aims to debate the advantages and disadvantages of making the `std::lazy` coroutine, as proposed in [@P3552R0], retain scheduler affinity.
In other words, should the default implementation of `std::lazy` return to the original scheduler after each `co_await`?”

# Motivation # {#motivation}

After [@P3552R0] was published, there was an extended debate on an internal forum dedicated to `std::execution` authors regarding the advantages and disadvantages of giving `std::lazy` scheduler affinity.

[@P3552R0] proposes scheduler affinity, primarily motivated by the fact that both `unifex::task` and `stdexec::task`, predecessors of `std::lazy`, support scheduler affinity. However, there are no clearly explained reasons for this decision. Some authors of these previous attempts cited “removing a whole class of bugs,” but no in-depth analysis was provided.

## Problem description {#problem_description}

Let us assume that `sched1`, `sched2` and `sched3` are objects of types that model the `execution::scheduler` concept, and that `snd1` and `snd2` are sender expressions.
Let us also assume the following coroutine:
```C++
// called on `sched1`
std::lazy<void> example_coro() {
  f1();
  co_await snd1; // completes on `sched2`
  f2();
  co_await snd2; // completes on `sched3`
  f3();
}
```

If we make `std::lazy` *scheduler affine*, we expect `f1()`, `f2()` and `f3()` to be called on threads belonging the `sched1`.
In other words, after a `co_await` expression, we always transition back to `sched1`, the scheduler on which the coroutine was started.

On the other hand, if `std::lazy` is not scheduler affine, then we expect:

- `f1()` to execute on a thread belonging to `sched1`;
- `f2()` to execute on a thread belonging to `sched2`;
- `f3()` to execute on a thread belonging to `sched3`;

In this case, each `co_await` expression dictates where the subsequent code executes.

The main debate revolved around whether `std::lazy` should be scheduler-affine **by default**.
The discussion considered the following factors:

* complexity
* correctness: making it easier to avoid certain classes of bugs
* known issues

Performance was also mentioned as a criterion, but the entire group agreed that this is a lower-importance criterion.

## Not a problem {#not_a_problem}

A quick read through this document may lead to the wrong conclusion that picking one side (scheduler affine or non-scheduler affine coroutine) will prevent code that wants the opposite choice to be written.
To dispel this, we provide a quick overview on how one can go from one side to the other, and the other way around.

First, if we assume that the coroutine from the above example is non-scheduler affine (the easier case), then, to ensure that we get the behavior of the scheduler affine version, the user needs to add `| continues_on(sched1)` at the end of each `co_await` expression:

```C++
std::lazy<void> example_coro() {
  f1();
  co_await (snd1 | continues_on(sched1));
  f2();
  co_await (snd2 | continues_on(sched1));
  f3();
}
```

The user manually controls what would be the schedulers on which `f2()` and `f3()` would run.

---

To go from a scheduler affine coroutine to one that does not jump back to the original scheduler, the authors of [@P3552R0] propose two alternatives.
The first one, is to pass an `inline_scheduler` inside a *context* template type used to construct instances of `std::lazy`.
This `inline_scheduler` will never switch threads and will continue the execution on the current thread.

The other alternative to allow `co_await` switch sechduler is to make it recognize certain expressions passed to it.
The paper cites the mechanism used by `unifex`:
```C++
auto previous = co_await co_continue_on(new_scheduler);
```

This fragment will allow the user to explicitly jump to a new scheduler, using the `co_await` construct.


# Complexity arguments # {#complexity}

## Con: Teachability and aligning with a simple conceptual model ## {#conceptual-model}

With the introduction of `std::execution` ([@P2300R10]) we can divide the execution of an expression in two modes: **sync** and **async**.
Conceptually we can distinguish between the two modes by looking at the two aspects related to the completion of of the corresponding work: the **time** and the **place** of the completion.
Thus, we have the following:

execution mode  completion time  completion place
--------------- ---------------- ------------------------------------------
**sync**        immediate        same thread
**async**       delayed          possible different thread (and scheduler)

If we manage to properly teach the C++ users these two modes, then all the other things in `std::execution` and related facilities are easy to understand.

Insofar as the argument goes, everything that deviates from this model is adding more complexity to C++, will confuse users and will lead to incorrect use.

A scheduler affine `std::lazy` would make the `co_await`-ed expressions something that is half-sync, half-async.
The completion time is delayed (*async*), but the completion place is on the same scheduler, making it *sync*.
The matter is even more complex, as the place is not fully *sync*, as landing on the same scheduler doesn't imply landing on the same thread.

In other words, a scheduler affine coroutine will make the `co_await`-ed expressions work differently than senders (in subtle ways), and will make the body of the coroutine behave differently than a synchronous function.
That is, `co_await snd; some_code()` will behave differently than `snd | then(some_code)`

In the spirit of the argument, users will get confused by this behavior, not fully understand how things are working, and this will eventually lead to bugs.

*Counter-argument*: coroutines do not need to try to be equivalent to sender pipe composition, as there are other differences as well (e.g., coroutines have lexical scope, exceptions in coroutines work "as usual", etc.)


## Con: Teachability on main uses of `std::lazy` ## {#teachability}

Moreover, considering that one of the purposes of `std::lazy` is to make senders more approachable, the argument also exposes the following teachability problem:

- we teach people "senders are good for asynchrony, making asynchrony safer"
- we say that "`std::lazy` makes sender more approachable"
- with scheduler affinity we are telling users "we limit asynchrony by default, because people find it hard to use it"

The above three points cannot be put together without some contradiction.

Having a teachability problem, we will make the adoption of `std::lazy` and `std::execution` harder, will confuse the users, and, eventually, this will lead to more bugs.

*Counter-argument*: Ensuring scheduler affinity of `co_await` statements is not making it less async.
It establishes an invariance for the coroutine function body.

## Pro: To some point, affinity improves reasoning ## {#pro-reasoning}

Let us revisit the above example:
```C++
std::lazy<void> example_coro() {
  f1();
  co_await snd1;
  f2();
  co_await snd2;
  f3();
}
```

Looking at the above code, one doesn't need to understand `snd1` or `snd2` (they may be coroutine functions with a lot of nested complexity), and still can reason the scheduler in which `f2()` and `f3()` are called: they will be called on the scheduler on which the coroutine was started (the same scheduler where `f1()` will be executed).

Affinity provides isolation. Isolation improves locality of reasoning.

For example a program using async features might have dedicated thread pools for:

- request acceptance,
- request handling,
- disk IO,
- logging,
- cron-like scheduled periodic tasks,
- etc.

These are modeled as schedulers, and affinity / isolation means that a piece of code doesn't hop from resource to resource in a (locally) unpredictable way.
Instead, it runs where it's put, unless explicit, visible code switches the thread of execution.

In such an application, programming must follow two rules:
- all coroutines should do work on the scheduler it was started from;
- all changes of execution context are explicit.
This offers a reduction of complexity, as we can have a global policy on how schedulers are used to execute the code in coroutines.

## Con: To some point, affinity degrades local reasoning  ## {#con-reasoning}

The same example can be read differently: scheduler affinity degrades local reasoning.

Just by looking at `example_coro()` in isolation we cannot tell where `f1()` will be called; depending on the callers, it may be executed on different schedulers.
However, if we don't have scheduler affinity, we can fully reason about where `f2()` and `f3()` will be executed; we know what `snd1` and `snd2` do, and we know on which scheduler they complete.
If the caller is unsure the completion scheduler of the two senders, we can always add a `| continues_on(sched1)` at the end of each `co_await` to force the execution to be on the desired scheduler

If we do have scheduler affinity, we lose the ability.
Just by looking at the `example_coro()` body, without knowing who will call it, we cannot tell where `f2()` and `f3()` will be executed.

The more callers such a coroutine has, the more the problem increases.

## Con: Complexity of the scheduler affinity and customization mechanisms ## {#con-inner-complexity}

Adding scheduler affinity increases the complexity of the proposed coroutine type in 3 areas:

- when specifying the effect of `co_await`;
- when specifying what the scheduler associated with the coroutine is;
- when specifying ways to allow the continuation to execute on the scheduler in which the `co_await`-ed operation completes.

Instead of describing `co_await snd1` as "it asynchronously executes `snd1` and yields its completion value", we have to describe it as "it asynchronously executes `snd1` and yields its completion value **and transfer the execution back to the original scheduler**".
This is an extra complexity we are adding to this coroutine type.

Specifying the scheduler associated with the coroutine is also non-trivial.
[@P3552R0] has a discussion on this topic; this touches several aspects:

- getting a scheduler from the environment of the receiver used for starting the coroutine;
- getting the scheduler from a context specified as a template parameter to `std::lazy`;
- defaulting to `any_scheduler` if no scheduler is specified (at this point `any_scheduler` is not proposed).

Finally, there is complexity for allowing users to avoid scheduler affinity or continue execution on specified schedulers.
As [@P3552R0] notes, scheduler affinity has performance costs, so users shall be able to avoid it.
Among the solutions explored in the paper there are:

- using `inline_scheduler` as a parameter for the coroutine type;
- specializing the coroutine type to a have a different effects when `co_await`-ing expressions like `co_continue_on(new_scheduler)`;
- detecting when a `co_await`-ed expression completes synchronously (to avoid performance penalty of an extra scheduling)
- detecting when there is no need to re-schedule the work if the `co_await`-ed expression completes on the same scheduler.


## Con: Implementation details may be leaking out ## {#con-leaking}

Let us assume that one writes a coroutine returning `std::lazy<void>` (with no extra template parameters).
According to the proposal, this will use scheduler affinity.
Let us assume that the initial implementation will work just fine in production for some time.

Then, after some time, a performance measurement yields that the coroutine can be optimized.
In particular, dropping scheduler affinity may be a good option.
One suggestion made by [@P3552R0] is to specify `inline_scheduler` in the context of `std::lazy`.
But, adding `inline_scheduler` actually changes the interface of coroutine.

Implementation details are leaking out; this is a direct effect of using scheduler affinity.

This is not a problem only with `inline_scheduler`.
Each time we want to change the default scheduler in which the coroutine "regular" code would be executed, we have to change the coroutine type.
This breaks encapsulation.

This problem can be solved by allowing `std::lazy` to change its default scheduler from inside of the coroutine.


# Correctness arguments # {#correctness}

The correctness arguments in this section are all based on the idea that people might have certain expectations on how the system behave, and, if these expectations are not met, bugs appear.
Therefore, we describe here different examples possibly showcasing different expectations.

## Pro: Relying on serialization of execution to avoid data-races ## {#pro-ex-serialization}

Because coroutines look like regular functions, users might expect to behave the same.
That is, people might use `std::lazy` on a single-threaded scheduler for mutual-exclusion, and relying on that serialization of execution to avoid data-races.

For example:
```C++
std::lazy<void> implicit_serialization_coro() {
  unprotected_access_to_resource_A_work1();
  co_await snd1;
  unprotected_access_to_resource_A_work2();
}
// at the same time, added on the same scheduler:
unprotected_access_to_resource_A_work3();
```

In this example, if we rely that access to resource *A* happens on the same thread, and we can use unprotected access, then having no scheduler affinity might lead to problems.
The `co_await` in the middle might change the scheduler, and suddenly the second work item will be executed on a different thread, and may lead to data-races when accessing resource *A*.

The problem here is that the original scheduler may have other work to be executed (in this example, `unprotected_access_to_resource_A_work3()`).
Without scheduler affinity `unprotected_access_to_resource_A_work2()` may be used on a different thread, so the serialization of work items is lost.

*Counter-argument*: This is an anti-pattern regardless of scheduler affinity for `std::lazy`.
Even with scheduler affinity, slightly tweaking the example, one can easily lead to data races.
We should teach users why this is a foot-gun, and should be avoided.
There are two main reasons for this:

* In a modern async world, one should not rely on thread-based serialization of work items; instead, the dependencies between work items should be made explicit.
* When combining old code with asynchronous code, one should properly isolate between the two worlds; in particular, one shall not rely on manual synchronization that is present both in synchronous and asynchronous code.


## Pro: Avoid accidentally blocking the I/O thread ## {#pro-ex-io-thread}

Let us look at the following coroutine, that will always be called from a scheduler that is not the I/O scheduler:

```C++
std::lazy<void> mixed_io_work() {
  auto data = co_await io_read_data();
  process_data(data);
}
```

In this example, we `co_await` a sender that represents some I/O work.
This produces some data that needs to be further processed.

The way that the code is set up, with scheduler affinity, the processing of the data happens of the scheduler in which the work was started, which presumably is not the I/O scheduler.
The code should work as expected.

If we do not have scheduler affinity, the processing of the data happens on the I/O scheduler, which may be surprising to users.
In this case, the processing of the data may accidentally block the I/O thread.

The frequency of these cases is proportional with the number of coroutines that do I/O + CPU and are started on a non-I/O scheduler.

## Con: Scheduler affinity may lead to blocking the I/O thread ## {#con-ex-io-thread}

The example from the previous section, can easily be turned in its head, and act as a counter-argument to scheduler affinity.
The above example only works when the coroutine is started on a scheduler that is not the I/O scheduler; this is not something that can be seen just by looking at the definition of the coroutine (see also [Con: To some point, affinity degrades local reasoning](#con-reasoning)).

To better counter-balance the example from the previous section, we translate (and slightly adapt) one example given in [@P2300R10] to use `std::lazy`:
```C++
std::lazy<void> process_request() {
  auto request = co_await starts_on(io_sched, read_request());
  auto validated_request = co_await starts_on(cpu_sched, validate_request(request));
  auto response = handle_request(validated_request);
  auto bytes = serialize_response(response);
  co_await starts_on(io_sched, write_response(bytes));
}
```

Moreover, let us assume that this code is started on the I/O scheduler (we just accepted a new connection).
In this case, if we would have scheduler affinity, then we would execute heavy CPU processing on the I/O thread, which is undesired.

One might argue that we should also add `co_await`s to the two functions that we should be using the CPU scheduler (`process_request()` and `serialize_response()`).
To make this example more realistic, we can assume that `process_request()` and `serialize_response()` are regular functions and cannot be directly `co_await`-ed.
That would make it more probable for the users to not add `co_await` for these calls.

Actually, taking this to the extreme, if we want to ensure that each chain of computation executes on the desired scheduler, one would have to add `co_await` to each call in a coroutine; that would reduce the usability of `std::lazy`.

The frequency of these cases is proportional with the number of coroutines that do I/O + CPU and are started on a I/O scheduler.
The main thread is frequently being used as I/O thread, or at least, a more constrained execution agent.
But, it's more often that the main thread schedules something on another scheduler than another scheduler spawning work to be executed on the main thread; after all, the entire program is started on the main thread.
With that in mind, it seems that the example in this section may be more frequent than the the one in the previous section.


## Neutral: For GUI threads, the corresponding schedulers may not be influenced by scheduler affinity ## {#neutral-gui}

One particularly interesting feedback came from people working on QT.
According to this feedback, all the coroutines will run everything on their scheduler anyway, so, in most cases, there is no switch of any kind.
Everything in a coroutine tends to be executed by one scheduler anyway.

In this case, having scheduler affinity does not help but also does not hurt.

## Pro: Accidentally blocking timer thread ## {#pro-timer-thread}

Another case in which scheduler affinity might help avoid bugs is when executing various work on timers.
Here is a code snippet showcasing a basic setup:

```C++
std::lazy<void> work_on_timer() {
  co_await timer_fired();
  do_work_after_timer_was_fired();
}
```

In this case, the user awaits the timer to be triggered and continues with some (possibly heavy) work.
With scheduler affinity, the processing will happen on the scheduler on which the coroutine was called; this is typically not the timer scheduler.
On the other hand, having no scheduler affinity will lead to executing the work on the timer thread.
This is typically not desired, and may lead to problems with other timers not triggering.

While one can devise a counter example that reverses the problem, the frequency of that example seems to be lower than of the example presented here.

Issues of this type appeared multiple times at Meta, leading to serious problems in production.



# Arguments based on known issues

## Pro: Deadlock without scheduler affinity ## {#pro-deadlock}

The example at [https://github.com/dietmarkuehl/P3552-task/blob/main/demo-async-lock.cpp](https://github.com/dietmarkuehl/P3552-task/blob/main/demo-async-lock.cpp) exemplifies a case in which scheduler affinity of `std::lazy` avoids a deadlock that would be present if no scheduler affinity was present.

Assuming that `queue` acts like a scheduler with one thread, the simplified example looks like:
```C++
std::lazy<void> deadlock_case(queue& q) {
  auto result = co_await request(17, q);
  sync_wait(request(0, q));
}
```

If `std::lazy` would not have scheduler affinity, the `sync_wait` call would have been made from the completion scheduler of the `co_await`-ed expression.
In this case, that would the scheduler corresponding to `q`.
But that means that we are waiting on the thread running `q` for some action on the same thread to be completed.
That leads to a deadlock.

With scheduler affinity, the `sync_wait` will be called on a thread belonging to the scheduler on which the coroutine was started.
Assuming that the coroutine was not started on the thread used by `q`, no deadlock would occur.

*Counter-argument*: The example is somehow contrived, and the effect of scheduler affinity is marginal here.
Some problems with this example:

- the deadlock comes from the misuse of `sync_wait`, which can be reproduced easily without the use of `std::lazy`;
- trying to `sync_wait` inside of a chain of asynchronous work is typically an anti-pattern;
- it's easy to twist the example to have deadlocks even in the presence of scheduler affinity; for example, starting the coroutine on the scheduler associated with `q`.

## Pro: Stack overflow ## {#pro-stack-overflow}

[@P3552R0] provides an example in which one can get into a situation of stack overflow without using scheduler affinity.
Here is a reproduction of the example:

```C++
lazy<void> stack_overflow_coro() {
  for (int i{}; i < 1000000; ++i)
    co_await just(i);
}
```

This problem is generated in cases in which we resume the work immediately after suspending.
Adding a jump to a different thread will delay the resumption of the work, avoiding the accumulation of stack usage.
The thread unwinds its stack until it reaches its own scheduling and picks up the next entity to execute.

## Con: `std::lazy` cannot be used in all places ## {#con-cannot-use}

Let us assume that we have a simple coroutine:

```C++
std::lazy<void> some_async_work() {
  co_await starts_on(sched1, work1);
  co_await starts_on(sched2, work2);
  co_await starts_on(sched3, work3);
}
```

This coroutine will execute three work items, on the appropriate schedulers.
We do not have actual code to be executed between the `co_await`s, thus we do not need a default scheduler.
It is reasonable to expect the users to not want to add a context to `std::lazy`.

This code can be used in some places successfully, either inside `co_await` expressions or in regular sender expressions.
After a time, we might have a need to use this through a `counting_scope` ([@P3149R8]), like in the following example:

```C++
counting_scope scope;
...
spawn(some_async_work(), scope.get_token());
...
```

The usage of `counting_scope` is not expected to be marginal.
People will want to use it in context in which they want to migrate from unstructured to structured concurrency, or when they need to have a dynamic number of work items to be executed dynamically (without having a clear way to place them in a work graph).

The problem is that, the above code does not compile.
`std::lazy` requires a default scheduler, and `counting_scope` cannot provide it.
There is also no scheduler specified as a template parameter to `std::lazy`.
The reader should notice that we don't even need a default scheduler in this example, as the body of the coroutine always specifies the scheduler in which the work needs to run.

As the use frequency of `counting_scope` is not expected to be negligible, this seems like a major drawback of the scheduler affinity requirements.


# Performance arguments # {#performance}

## Con: Extra cost for jumping when we don't need to execute anything in the coroutine ## {#con-perf-coro-nothing}

Let's assume we have the following example:

```C++
std::lazy<void> useless_jump_to_original_scheduler(my_data data) {
  auto r1 = co_await starts_on(sched1, work1(data));
  auto r2 = co_await starts_on(sched2, work2(r1));
  auto r3 = co_await starts_on(sched3, work2(r2));
  co_await starts_on(sched4, work2(r3));
}
```

Here, the coroutine processes the given data in a pipeline fashion, with four different stages.
For each stage of the pipeline we have a dedicated scheduler to perform the work.
The entirety of work is divided between these four schedulers, and there is no work that needs to be scheduled outside of these schedulers.

Let us also assume that the coroutine was started on scheduler `sched0`.
That means that, with scheduler affinity, after each `co_await` call we transition back to `sched0`, just to transition to the next scheduler.
The extra transitions to `sched0` are not helping at all, but the do incur a performance penalty.

This example is somehow atypical as the entire body of the coroutine is a series of `co_await`s.
We can easily adapt the example to add some more processing on the coroutine, like the following:
```C++
std::lazy<void> useless_jump_to_original_scheduler(my_data data) {
  auto r1 = co_await starts_on(sched1, work1(data));
  validate1(r1);
  auto r2 = co_await starts_on(sched2, work2(r1));
  validate2(r2);
  auto r3 = co_await starts_on(sched3, work2(r2));
  validate3(r3);
  co_await starts_on(sched4, work2(r3));
}
```

We assume that the the work done by `validate1`, `validate2` and `validate3` is small enough that it does not matter on which scheduler is executed.
Even in this case, if there are no constraints on where the extra work needs to be executed, switching back to `sched0` to execute the `validateN` functions is a performance cost that should be avoided.


## Con: Extra cost for jumping to the same scheduler ## {#con-perf-jump-to-same}

Let us assume we have the following coroutine:
```C++
// started on `sched0`
std::lazy<void> jumping_coro() {
  co_await work() // completes on `sched1`
  other_work();
}
```

Here, with scheduler affinity, we will execute `other_work()` on `sched0`, i.e., the scheduler on which the coroutine was started.
If `work()` completes on `sched1`, we need a jump to `sched0`.

But, what happens if `sched0 == sched1`?
We will do an extra jump that is not needed.


# Bottom line # {#bottom-line}

The paper discusses some pros and cons of using scheduler affinity for `std::lazy`.

To have a good decision on whether scheduler affinity should be the default or not for `std::lazy` we need to better balance the different tradeoffs.
For example, are the examples in which scheduler affinity helps more important than the growth in complexity?

# Appendix: Other ideas

Because both the presence and absence of scheduler affinity have downside, maybe other ideas should be explored to hopefully find some compromises.
This section lists some ideas that might help

## Make scheduler affinity opt-in from the body of the coroutine

Here is an example how this might work:
```C++
std::lazy<void> encapsulated_scheduler_affinity() {
  co_await lazy_set_scheduler_affinity(sched0);

  f1();          // executed  on `sched0`
  co_await snd1; // completes on `sched2`
  f2();          // executed  on `sched0`
  co_await snd2; // completes on `sched3`
  f3();          // executed  on `sched0`
}
```

There are two points here that are noteworthy:
- scheduler affinity is a local concern; abstraction does not leak outside;
- scheduler affinity is opt-in; user always has control when scheduler affinity needs to be turned on, and which scheduler should be used.

This idea would help in the following points:

- [Con: Teachability and aligning with a simple conceptual model](#conceptual-model)
- [Con: Teachability on main uses of `std::lazy`](#teachability)
- [Con: To some point, affinity degrades local reasoning](#con-reasoning)
- [Con: Implementation details may be leaking out](#con-leaking)
- [Con: `std::lazy` cannot be used in all places](#con-cannot-use)
- [Con: Extra cost for jumping when we don’t need to execute anything in the coroutine](#con-perf-coro-nothing)
- [Con: Extra cost for jumping to the same scheduler](#con-perf-jump-to-same)

## Check for scheduler affinity, instead of enforcing it ## {#check-by-default}

One of the problems with both scheduler affinity or the lack of scheduler affinity is the fact that it mandates a default behavior when the intent of the user is ambiguous.
Maybe another approach is to force the user to specify the intent.

The coroutine can be set up in four different modes:

1. check that `co_await`s don't change the scheduler (default option);
1. check that if `co_await` completes on a scheduler, that scheduler is equal to a given scheduler (check for scheduler affinity);
1. apply scheduler affinity for a specified scheduler for every `co_await` call;
1. disable scheduler affinity, and allow `co_awaits` to change the scheduler for the rest of the body of the coroutine.

Except the first option, all the other options require user explicit specification of the intent.
The intent is specified in the body of the coroutine, as opposed that as a template parameter to `std::lazy`; this will make the implementation details not leak in the coroutine signature.

Except the third option, all the other options will treat an expression like `co_await snd` as not having scheduler affinity, if `snd` does not advertizes a completion scheduler.

In all options, `co_await`ing on a sender produced by `execution::on()` will just asynchronously execute that sender without further transferring control to any scheduler.

In the first option, for a `co_await snd` expression, if `snd` advertize a completion scheduler, then issue a compilation error informing the user that, by default, schedulers should not be changed without explicit control.
Otherwise, execute the async computation indicated by `snd`, without transferring control to any scheduler.

That second option will be selected if `co_await lazy_check_completion_scheduler(sched0)` expression is found in the body of the coroutine.
This will tell `std::lazy` that all `co_await` expressions that try to change the scheduler must complete on `sched0`.
If a `co_await`ed sender advertizes a completion scheduler different than `sched0`, a compilation error is expected.

The third option will be selected if `co_await lazy_set_scheduler_affinity(sched0)` expression is found in the body of the coroutine.
In this case, after each `co_await snd`, a re-posting to `sched0` will happen, regardless of whether `snd` advertizes its affinity or not, regardless on which scheduler `snd` completes.

The third option will be selected if `co_await lazy_set_no_scheduler_affinity()` expression is found in the body of the coroutine.
In this case, no scheduler affinity is checked or enforced, and all `co_await`s are allowed to change the scheduler for the following code to be executed.

The four modes can be combined in the same coroutine.

Here is an example of a coroutine with all the modes, showcasing interaction with sender produced by common algorithms:
```C++
std::lazy<void> coro_with_all_modes() {
  // Mode 1
  co_await just() // ok
  co_await on(sched1, snd) // ok
  co_await schedule(sched1) // error: explicit scheduler switch handling is needed

  // Mode 2
  co_await lazy_check_completion_scheduler(sched1);
  co_await just() // ok
  co_await on(sched1, snd) // ok
  co_await on(sched2, snd) // ok
  co_await schedule(sched1) // ok
  co_await schedule(sched2) // error: unexpected completion scheduler

  // Mode 3
  co_await lazy_set_scheduler_affinity(sched1);
  co_await just() // ok
  co_await on(sched1, snd) // ok
  co_await on(sched2, snd) // ok
  co_await schedule(sched1) // ok
  co_await schedule(sched2) // ok; transfer back to sched1

  // Mode 4
  co_await lazy_set_scheduler_affinity(sched1);
  co_await just() // ok
  co_await on(sched1, snd) // ok
  co_await on(sched2, snd) // ok
  co_await schedule(sched1) // ok
  co_await schedule(sched2) // ok; transfer back to sched1
  f() // execution will continue on `sched2`
}
```

This approach fixes most of the downsides with both scheduler affinity and the lack of scheduler affinity.
Whenever there is a case in which the presence or absence of scheduler affinity can affect the correctness of the code, and the behavior is not explicitly indicated by the user, a compilation error is produced.
The coroutines that do not change schedulers will work just fine without user intervention.
The coroutines that change the schedulers will require the user to explicitly specify the desired behavior.


## Hide the schedulers for resources to be protected (timers, I/O)

One problem with the example from [Pro: Accidentally blocking timer thread](#pro-timer-thread) is that the user can directly access the scheduler for the timer.
Instead, an abstraction shall be provided that always take a scheduler.

With that idea in mind, the problematic example would become:
```C++
std::lazy<void> work_on_timer() {
  co_await on_timer(sched1, do_work_after_timer_was_fired());
}

auto on_timer(scheduler auto sched, sender auto snd) {
  return protected_timer_sender
       | continues_on(sched)
       | let_value([]() {
        return std::move(snd);
       })
}
```

The main idea here is that we protect the time scheduler/sender.
Users cannot access to it directly.
Instead, they need to go through a `on_timer` abstraction that ensures that the given work is executed on the appropriate scheduler, and not on the timer scheduler.

Please note that this is a solution outside of `std::lazy`.

This idea might help on [Pro: Accidentally blocking timer thread](#pro-timer-thread), but it can be also employed for [Pro: Avoid accidentally blocking the I/O thread](#pro-ex-io-thread).
