(* chan.sig — buffered FIFO channels and a sequential process runner.
   send/recv are non-blocking (recv on an empty channel raises Fail);
   run executes processes in order. Not a coroutine/preemptive scheduler. *)

signature CHAN =
sig
  type 'a chan
  type process = unit -> unit

  val channel : unit -> 'a chan
  val send : 'a chan -> 'a -> unit
  val recv : 'a chan -> 'a
  val spawn : process -> process
  val run : process list -> unit
end
