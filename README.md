# sml-chan

[![CI](https://github.com/sjqtentacles/sml-chan/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-chan/actions/workflows/ci.yml)

Buffered FIFO channels and a sequential process runner for Standard ML. Channels
are unbounded queues you `send` to and `recv` from; the runner executes a list
of processes in order. It is a lightweight, single-threaded message-passing
utility — not a preemptive or coroutine scheduler.

## API sketch

```sml
(* A typed, unbounded FIFO channel *)
val ch : int Chan.chan = Chan.channel ()

Chan.send ch 1                 (* enqueue (never blocks) *)
Chan.send ch 2
val x = Chan.recv ch           (* dequeue front: 1 *)

(* Processes are just `unit -> unit` thunks *)
val p : Chan.process = Chan.spawn (fn () => print "hi\n")
Chan.run [p1, p2, p3]          (* run each process to completion, in order *)
```

```sml
val ch = Chan.channel ()
val () = (Chan.send ch 1; Chan.send ch 2; Chan.send ch 3)
val () = Chan.run [ fn () => print (Int.toString (Chan.recv ch))
                  , fn () => print (Int.toString (Chan.recv ch)) ]  (* "12" *)
```

## Semantics and limitations

Be aware of what this is and is **not**:

- **Buffered, non-blocking `send`.** A channel is an unbounded queue
  (`'a list ref`); `send` appends and returns immediately. There is **no
  rendezvous** — `send` does not wait for a `recv`.
- **`recv` does not block.** Receiving from an empty channel raises
  `Fail "recv on empty channel"`. Make sure a value has been sent first (or
  catch the exception).
- **Sequential runner.** `Chan.run ps` simply runs each process to completion in
  list order (`List.app`). It is **not** a cooperative or preemptive scheduler:
  it does not interleave processes or suspend one that "blocks". `spawn` returns
  the process thunk unchanged.
- **Single-threaded.** No OS threads, no parallelism, no `select`/`alt`.

For interleaved cooperative execution you would need a continuation-based
scheduler, which this library does not provide.

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
  chan.sml     buffered FIFO channel + sequential runner
  chan.mlb
test/
  test.sml     FIFO ordering, recv-empty error, run order
```

## License

MIT. See [LICENSE](LICENSE).
