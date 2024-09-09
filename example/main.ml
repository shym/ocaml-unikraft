(* SPDX-License-Identifier: MIT
 * Copyright (c) 2024 Samuel Hym, Tarides <samuel@tarides.com>
 *)

(* Various small examples *)

let greeter () = Printf.printf "Hello from OCaml on Unikraft!\n%!"

let sleeper () =
  Printf.printf "1\n%!";
  for i = 2 to 5 do
    Unix.sleep 1;
    Printf.printf "%d\n%!" i
  done

let arg_displayer () =
  for i = 0 to Array.length Sys.argv - 1 do
    Printf.printf "Sys.argv.(%d) = %s\n" i Sys.argv.(i)
  done

let choice =
  let str = if Array.length Sys.argv = 1 then "default" else Sys.argv.(1) in
  match str with
  | "hello" | "default" -> greeter
  | "sleep" -> sleeper
  | "args" -> arg_displayer
  | _ ->
      Printf.printf "Warning: unknown argument \"%s\"\n" str;
      Printf.printf "Possible arguments: hello, sleep, args or default\n";
      greeter

let _ =
  choice ();
  Printf.printf "Exiting\n%!"
