# sml-chan

[![CI](https://github.com/sjqtentacles/sml-chan/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-chan/actions/workflows/ci.yml)

Buffered FIFO channels (unbounded or bounded) plus a deterministic cooperative
run-to-completion scheduler for Standard ML. Channels are amortized-O(1) queues
backed by a front/back two-list; `send` never blocks (unless a bounded channel
is full). The scheduler runs queued thunks in FIFO order and lets a running task
`fork` more work. It is single-threaded message passing — not preemptive and not
continuation-based.

## API sketch

```sml
(* unbounded and bounded channels *)
val ch : int Chan.chan = Chan.channel ()      (* unbounded *)
val bd : int Chan.chan = Chan.channelN 2      (* bounded to 2 items *)

Chan.send ch 1                  (* enqueue (raises Chan.Full if bounded+full) *)
val ok = Chan.trySend bd 2      (* false instead of raising when full *)
val x  = Chan.recv ch           (* dequeue front; raises Chan.Empty if empty *)
val y  = Chan.tryRecv ch        (* NONE if empty *)

Chan.peek ch                    (* front without removing *)
Chan.length ch                  (* item count *)
Chan.isEmpty ch                 (* bool *)
Chan.isFull bd                  (* bool (always false for unbounded) *)
Chan.capacity bd                (* SOME 2 / NONE *)
Chan.toList ch                  (* front-to-back, non-destructive *)
Chan.drain ch                   (* remove + return all, front-to-back *)
Chan.fromList [1,2,3]           (* seed a channel front-to-back *)
Chan.recvN ch 2                 (* up to n items *)
Chan.sendAll ch [4,5]           (* enqueue a batch *)
```

### Cooperative scheduler

```sml
val sc = Chan.scheduler ()
val () = Chan.fork sc (fn () => print "a")
val () = Chan.fork sc (fn () =>
           (print "b"; Chan.fork sc (fn () => print "d")))  (* fork mid-run *)
val () = Chan.fork sc (fn () => print "c")
val () = Chan.runAll sc          (* prints "abcd" — FIFO, forks run after the queue *)
```

The original sequential runner is kept for back-compat: `Chan.spawn` is the
identity on `unit -> unit` thunks and `Chan.run ps` runs each in list order.

## Semantics and limitations

- **Amortized-O(1) queue.** Backed by a front/back two-list; `send`/`recv` are
  amortized constant time (the old `'a list ref` made `send` O(n)).
- **Non-blocking `send`.** No rendezvous: `send` returns immediately. On a
  **bounded** channel `send` raises `Chan.Full` when full; use `trySend` to get
  a boolean instead.
- **`recv` does not block.** Receiving from an empty channel raises `Chan.Empty`;
  use `tryRecv`/`peek`/`recvN` for non-raising access.
- **Cooperative, run-to-completion scheduler.** `runAll` drains a FIFO work
  queue; a running task may `fork` more tasks, which run after the current queue
  position. It does **not** preempt or suspend a "blocked" task — there are no
  continuations and no parallelism. The order is deterministic.
- **Single-threaded.** No OS threads, no `select`/`alt`.

## Installing with smlpkg

```sh
smlpkg add github.com/sjqtentacles/sml-chan
smlpkg sync
```

Reference from your `.mlb`:

```
lib/github.com/sjqtentacles/sml-chan/chan.mlb
```

## Building and testing

```sh
make test        # MLton
make test-poly   # Poly/ML
make all-tests   # both
make clean
```

## Project layout

```
sml.pkg
Makefile
lib/github.com/sjqtentacles/sml-chan/
  chan.sig     CHAN signature
  chan.sml     two-list FIFO channels + bounded channels + cooperative scheduler
  chan.mlb
test/
  test.sml     FIFO ordering, bounded channels, queue API, scheduler
```

## License

MIT. See [LICENSE](LICENSE).
