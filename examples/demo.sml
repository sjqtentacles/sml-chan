(* demo.sml - unbounded and bounded channels, a list-seeded channel drained
   via recvN/toList/drain, and the cooperative FIFO scheduler with a mid-run
   fork. Deterministic: no wall-clock, no unseeded randomness, identical
   output on every run and both compilers. *)

val () = print "Unbounded channel:\n"
val ch = Chan.channel ()
val () = Chan.send ch 1
val () = Chan.send ch 2
val () = Chan.send ch 3
val () = print ("  peek   = "
                ^ (case Chan.peek ch of SOME x => Int.toString x | NONE => "NONE")
                ^ "\n")
val () = print ("  recv   = " ^ Int.toString (Chan.recv ch) ^ "\n")
val () = print ("  length = " ^ Int.toString (Chan.length ch) ^ "\n")

val () = print "\nBounded channel (capacity 2):\n"
val bd = Chan.channelN 2
val r1 = Chan.trySend bd 10
val r2 = Chan.trySend bd 20
val r3 = Chan.trySend bd 30
val () = print ("  trySend results = ["
                ^ String.concatWith "," (List.map Bool.toString [r1, r2, r3])
                ^ "]\n")
val () = print ("  isFull = " ^ Bool.toString (Chan.isFull bd) ^ "\n")

val () = print "\nList-seeded channel [1,2,3,4,5]:\n"
val lc = Chan.fromList [1,2,3,4,5]
val firstThree = Chan.recvN lc 3
val () = print ("  recvN 3            = ["
                ^ String.concatWith "," (List.map Int.toString firstThree)
                ^ "]\n")
val () = print ("  toList (remainder) = ["
                ^ String.concatWith "," (List.map Int.toString (Chan.toList lc))
                ^ "]\n")
val drained = Chan.drain lc
val () = print ("  drain              = ["
                ^ String.concatWith "," (List.map Int.toString drained)
                ^ "]\n")
val () = print ("  tryRecv on emptied channel = "
                ^ (case Chan.tryRecv lc of SOME x => Int.toString x | NONE => "NONE")
                ^ "\n")

val () = print "\nCooperative scheduler:\n"
val sc = Chan.scheduler ()
val () = print ("  pending before = " ^ Int.toString (Chan.pending sc) ^ "\n")
val () = Chan.fork sc (fn () => print "  task a\n")
val () = Chan.fork sc (fn () =>
           (print "  task b\n"; Chan.fork sc (fn () => print "  task d (forked by b)\n")))
val () = Chan.fork sc (fn () => print "  task c\n")
val () = Chan.runAll sc
val () = print ("  pending after  = " ^ Int.toString (Chan.pending sc) ^ "\n")
