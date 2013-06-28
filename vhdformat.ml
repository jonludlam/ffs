(*
 * Copyright (C) Citrix Systems Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation; version 2.1 only. with the special
 * exception on linking described in file LICENSE.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *)

open Int64

let kib = 1024L
let mib = mul kib kib
let gib = mul kib mib
let mib_minus_1 = sub mib 1L
let two_mib = mul mib 2L
let max_size = mul gib 2040L

let roundup v block =
  mul block (div (sub (add v block) 1L) block)

let create path size =
  let size = roundup size two_mib in
  if size < mib or size > max_size
  then failwith (Printf.sprintf "VDI size must be between 1 MiB and %Ld MiB" max_size)

let destroy path =
  (* TODO: GC *)
  try Unix.unlink path with _ -> ()

let my_context = ref (Tapctl.create ())
let ctx () = !my_context

let t_detach t = Tapctl.detach (ctx ()) t; Tapctl.free (ctx ()) (Tapctl.get_minor t)
let t_pause t =  Tapctl.pause (ctx ()) t
let t_unpause t = Tapctl.unpause (ctx ()) t
let get_paused t = Tapctl.is_paused (ctx ()) t
let get_activated t = Tapctl.is_active (ctx ()) t

let attach _ =
  let minor = Tapctl.allocate (ctx ()) in
  let tid = Tapctl.spawn (ctx ()) in
  let dev = Tapctl.attach (ctx ()) tid minor in
  let dest = Tapctl.devnode (ctx ()) (Tapctl.get_minor dev) in
  dest

let activate dev file ty =
  let dev, _, _ = Tapctl.of_device (ctx ()) dev in
  if not (get_activated dev) then begin
    Tapctl._open (ctx ()) dev file ty
  end else begin
    t_pause dev;
    Tapctl.unpause (ctx ()) dev file ty
  end

let deactivate dev =
  let dev, _, _ = Tapctl.of_device (ctx ()) dev in
  Tapctl.close (ctx ()) dev

let detach dev =
  let dev, _, _ = Tapctl.of_device (ctx ()) dev in
  t_detach dev