structure Tests =
struct
  open Harness
  structure C = Chan
  fun run () =
  let
    val ch = C.channel ()
    val order = ref []
    val () = section "producer/consumer FIFO ordering"
    val () = (C.send ch 1; C.send ch 2; C.send ch 3)
    val () = C.run [ fn () => order := C.recv ch :: !order
                   , fn () => order := C.recv ch :: !order
                   , fn () => order := C.recv ch :: !order ]
    val () = checkIntList "fifo order" ([3,2,1], !order)

    val () = section "recv on empty channel raises"
    val empty : int C.chan = C.channel ()
    val () = checkRaises "recv empty" (fn () => C.recv empty)

    val () = section "interleaved send/recv preserves FIFO"
    val c2 = C.channel ()
    val () = C.send c2 10
    val () = checkInt "first out" (10, C.recv c2)
    val () = (C.send c2 20; C.send c2 30)
    val () = checkInt "next out" (20, C.recv c2)
    val () = checkInt "then out" (30, C.recv c2)

    val () = section "run executes processes in list order"
    val log = ref []
    val () = C.run [ C.spawn (fn () => log := "a" :: !log)
                   , C.spawn (fn () => log := "b" :: !log)
                   , C.spawn (fn () => log := "c" :: !log) ]
    val () = checkString "ran a,b,c in order" ("cba", String.concat (!log))

    (* ---- length / isEmpty / peek / clear ---- *)
    val () = section "length / isEmpty / peek"
    val c3 = C.channel ()
    val () = checkBool "starts empty" (true, C.isEmpty c3)
    val () = checkInt "length 0" (0, C.length c3)
    val () = (C.send c3 1; C.send c3 2)
    val () = checkInt "length 2" (2, C.length c3)
    val () = checkBool "not empty" (false, C.isEmpty c3)
    val () = checkInt "peek front" (1, valOf (C.peek c3))
    val () = checkInt "peek does not remove" (2, C.length c3)
    val () = C.clear c3
    val () = checkBool "cleared empty" (true, C.isEmpty c3)

    (* ---- tryRecv ---- *)
    val () = section "tryRecv"
    val c4 = C.channel ()
    val () = checkBool "tryRecv empty NONE"
               (true, case C.tryRecv c4 of NONE => true | _ => false)
    val () = C.send c4 99
    val () = checkInt "tryRecv SOME" (99, valOf (C.tryRecv c4))

    (* ---- FIFO across the front/back boundary (stress the two-list reverse) ---- *)
    val () = section "FIFO across reversal boundary"
    val c5 = C.channel ()
    val () = C.sendAll c5 [1,2,3]
    val a = C.recv c5            (* forces a reversal *)
    val () = C.sendAll c5 [4,5]  (* now goes to `back` *)
    val () = checkIntList "interleaved fifo" ([1,2,3,4,5], a :: C.drain c5)

    (* ---- fromList / toList / drain ---- *)
    val () = section "fromList / toList / drain"
    val c6 = C.fromList [7,8,9]
    val () = checkIntList "toList non-destructive" ([7,8,9], C.toList c6)
    val () = checkInt "length unchanged by toList" (3, C.length c6)
    val () = checkIntList "drain returns all" ([7,8,9], C.drain c6)
    val () = checkBool "drained empty" (true, C.isEmpty c6)

    (* ---- recvN ---- *)
    val () = section "recvN"
    val c7 = C.fromList [1,2,3,4]
    val () = checkIntList "recvN 2" ([1,2], C.recvN c7 2)
    val () = checkIntList "recvN over-count" ([3,4], C.recvN c7 10)
    val () = checkIntList "recvN on empty" ([], C.recvN c7 3)

    (* ---- bounded channel ---- *)
    val () = section "bounded channel"
    val b = C.channelN 2
    val () = checkBool "capacity SOME 2"
               (true, case C.capacity b of SOME 2 => true | _ => false)
    val () = checkBool "trySend 1 ok" (true, C.trySend b 1)
    val () = checkBool "trySend 2 ok" (true, C.trySend b 2)
    val () = checkBool "isFull" (true, C.isFull b)
    val () = checkBool "trySend 3 rejected" (false, C.trySend b 3)
    val () = checkInt "length still 2" (2, C.length b)
    val () = checkRaises "send when full raises" (fn () => C.send b 3)
    val () = checkInt "recv frees a slot" (1, C.recv b)
    val () = checkBool "trySend after recv ok" (true, C.trySend b 4)
    val () = checkIntList "bounded fifo" ([2,4], C.drain b)
    val () = checkBool "unbounded never full" (false, C.isFull (C.channel ()))

    (* ---- cooperative scheduler ---- *)
    val () = section "cooperative scheduler (FIFO, forks compose)"
    val sc = C.scheduler ()
    val trace = ref []
    fun note s = trace := s :: !trace
    val () = C.fork sc (fn () => note "a")
    val () = C.fork sc (fn () =>
               (note "b"; C.fork sc (fn () => note "d")))  (* d forked mid-run *)
    val () = C.fork sc (fn () => note "c")
    val () = checkInt "3 pending before run" (3, C.pending sc)
    val () = C.runAll sc
    (* a, b, c run; b forks d which runs after c -> order a b c d *)
    val () = checkString "round-robin order" ("abcd", String.concat (List.rev (!trace)))
    val () = checkInt "drained" (0, C.pending sc)
  in Harness.run () end
end
