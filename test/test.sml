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
  in Harness.run () end
end
