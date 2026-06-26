(* chan.sig — buffered FIFO channels, bounded channels, and a deterministic
   cooperative (run-to-completion) scheduler.

   Channels are amortized-O(1) queues backed by a front/back two-list. `send`
   never blocks; `recv` on an empty channel raises `Empty` (the original
   `Fail "recv on empty channel"` behavior is preserved via an exception).

   The scheduler runs queued thunks in FIFO order; a running task may `fork`
   further tasks, which are appended and run after the current batch. It is
   single-threaded and run-to-completion (no preemption / no continuations),
   but it is a real work queue: forks compose and the order is deterministic. *)

signature CHAN =
sig
  type 'a chan
  type process = unit -> unit

  exception Empty
  exception Full

  (* ---- construction ---- *)
  val channel  : unit -> 'a chan          (* unbounded *)
  val channelN : int -> 'a chan           (* bounded to `n` items (n >= 0) *)
  val fromList : 'a list -> 'a chan        (* unbounded, seeded front-to-back *)

  (* ---- sending ---- *)
  val send    : 'a chan -> 'a -> unit      (* enqueue; raises Full if bounded+full *)
  val trySend : 'a chan -> 'a -> bool      (* false (no enqueue) if bounded+full *)
  val sendAll : 'a chan -> 'a list -> unit (* enqueue each (raises Full as needed) *)

  (* ---- receiving ---- *)
  val recv    : 'a chan -> 'a              (* dequeue front; raises Empty if empty *)
  val tryRecv : 'a chan -> 'a option       (* NONE if empty *)
  val recvN   : 'a chan -> int -> 'a list  (* up to n items, front-to-back *)
  val peek    : 'a chan -> 'a option       (* front without removing *)

  (* ---- inspection ---- *)
  val isEmpty  : 'a chan -> bool
  val isFull   : 'a chan -> bool
  val length   : 'a chan -> int
  val capacity : 'a chan -> int option     (* NONE = unbounded *)
  val clear    : 'a chan -> unit
  val drain    : 'a chan -> 'a list        (* remove and return all, front-to-back *)
  val toList   : 'a chan -> 'a list        (* front-to-back, non-destructive *)

  (* ---- sequential runner (back-compat) ---- *)
  val spawn : process -> process           (* identity; kept for back-compat *)
  val run   : process list -> unit         (* run each thunk in order *)

  (* ---- cooperative run-to-completion scheduler ---- *)
  type scheduler
  val scheduler : unit -> scheduler        (* empty scheduler *)
  val fork      : scheduler -> process -> unit  (* enqueue a task *)
  val runAll    : scheduler -> unit        (* run queued tasks FIFO until drained *)
  val pending   : scheduler -> int         (* number of not-yet-run tasks *)
end
