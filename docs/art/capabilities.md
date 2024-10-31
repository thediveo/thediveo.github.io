---
title: "C(r)apabilities Illustrated"
description: "Professor Lipton and the Diabolical POSIX Legacy."
---

# C(r)apabilities Illustrated

[Linux capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html)
– the posterchildren of security. Most funny when combined with such advice such
as not running as root (especially in containers) because that is "best
practise". If people say so, then it must be.

I rather prefer to refer to this as "crapabilities", for reasons outlined below.

## Eight Shades of Crapability

My personal favorite is to ask people praising capabilities how many sets they
know of – only to see them fold.

Time for an illustration to rip the illusion apart.

![capabilities](/_images/capabilities.svg)

To answer my question, there are actually **eight sets**: first, a group of
_five_ capabilities sets for threads (tasks, processes) and then another group
of _three_ capabilities sets for files. Please note that I use (as usually) in
this context the terms _thread_ and _task_ interchangeably.

- **thread capabilities**
  - **effective capabilities** – only these capabilities decide what a thread is
    able to do, to "effect".
  - **permitted capabilities** define what capabilities a thread can make
    effective, but no other.
  - **inheritable capabilities** – which, to cut a long story short, are a
    totally FUBAR'd design and better forgotten.
  - **bounding capabilities** represent an automatically inherited restriction
    on the available capabilities that can never be lifted, but only more
    restricted.
  - **ambient capabilities** are the desperate attempt to somehow fix the problem of
    passing a controlled set of effective capabilities onto a child without
    giving the child's executable powerful file capabilities.
- **file capabilities** can give binaries more fine-graned super powers, such as
  `CAP_DISH_WASHING`:
  - **effective file capabilities** are actually due to austerity only a single
    flag that switches on and off all effective capabilities together.
  - **permitted file capabilities** then are fine-grained again.
  - **inheritable capabilities** are also fine-grained.

What is important to understand is that **file capabilities never fully control
a child's capabilities**. Instead they get combined in a non-obvious manner (as
illustrated above) with the parent process's effective UID, as well inheritable,
bounding and ambient capabilities.

To add more fun, there's a non-trivial API so that threads can modify their
various capabilities sets.

## Post Scriptum

It is malicious gossip that this architecture originally was one of the puzzles
to solve in a Professor Lipton portable game. It _must be_.
