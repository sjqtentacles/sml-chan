structure Chan :> CHAN =
struct
  type process = unit -> unit

  exception Empty
  exception Full

  (* Amortized-O(1) FIFO queue: `front` is dequeue order, `back` is reversed
     enqueue order. When `front` empties we reverse `back` into it. `cap` is the
     optional bound, `n` the current item count. *)
  type 'a chan = { front : 'a list ref, back : 'a list ref,
                   n : int ref, cap : int option }

  fun channel () : 'a chan =
    { front = ref [], back = ref [], n = ref 0, cap = NONE }

  fun channelN k : 'a chan =
    { front = ref [], back = ref [], n = ref 0,
      cap = SOME (if k < 0 then 0 else k) }

  fun length (ch : 'a chan) = ! (#n ch)
  fun isEmpty (ch : 'a chan) = ! (#n ch) = 0
  fun capacity (ch : 'a chan) = #cap ch
  fun isFull (ch : 'a chan) =
    case #cap ch of NONE => false | SOME c => ! (#n ch) >= c

  fun trySend (ch : 'a chan) x =
    if isFull ch then false
    else (#back ch := x :: ! (#back ch); #n ch := ! (#n ch) + 1; true)

  fun send ch x = if trySend ch x then () else raise Full

  fun sendAll ch xs = List.app (fn x => send ch x) xs

  (* Move `back` into `front` (reversed) when `front` is exhausted. *)
  fun normalize (ch : 'a chan) =
    case ! (#front ch) of
        [] => (#front ch := List.rev (! (#back ch)); #back ch := [])
      | _  => ()

  fun peek (ch : 'a chan) =
    (normalize ch; case ! (#front ch) of [] => NONE | x :: _ => SOME x)

  fun tryRecv (ch : 'a chan) =
    (normalize ch;
     case ! (#front ch) of
         [] => NONE
       | x :: xs => (#front ch := xs; #n ch := ! (#n ch) - 1; SOME x))

  fun recv ch = case tryRecv ch of SOME x => x | NONE => raise Empty

  fun recvN ch k =
    let
      fun loop (0, acc) = List.rev acc
        | loop (i, acc) =
            case tryRecv ch of
                NONE => List.rev acc
              | SOME x => loop (i - 1, x :: acc)
    in if k <= 0 then [] else loop (k, []) end

  fun toList (ch : 'a chan) = (normalize ch; ! (#front ch) @ List.rev (! (#back ch)))

  fun clear (ch : 'a chan) = (#front ch := []; #back ch := []; #n ch := 0)

  fun drain ch = let val xs = toList ch in clear ch; xs end

  fun fromList xs =
    let val ch = channel () in sendAll ch xs; ch end

  fun spawn f = f
  fun run ps = List.app (fn p => p ()) ps

  (* Cooperative run-to-completion scheduler: a FIFO work queue of thunks. A
     running task may `fork` more tasks; they run after the queue advances. *)
  type scheduler = process chan
  fun scheduler () : scheduler = channel ()
  fun fork (sc : scheduler) (f : process) = send sc f
  fun pending (sc : scheduler) = length sc
  fun runAll (sc : scheduler) =
    case tryRecv sc of
        NONE => ()
      | SOME task => (task (); runAll sc)
end
