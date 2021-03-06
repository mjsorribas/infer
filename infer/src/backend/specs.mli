(*
 * Copyright (c) 2009 - 2013 Monoidics ltd.
 * Copyright (c) 2013 - present Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *)

open! IStd

(** Specifications and spec table *)

(** {2 Spec Tables} *)

(** Module for joined props: the result of joining together propositions repeatedly *)
module Jprop : sig
  (** Remember when a prop is obtained as the join of two other props; the first parameter is an id *)
  type 'a t = Prop of int * 'a Prop.t | Joined of int * 'a Prop.t * 'a t * 'a t

  val compare : 'a t -> 'a t -> int
  (** Comparison for joined_prop *)

  val equal : 'a t -> 'a t -> bool
  (** Return true if the two join_prop's are equal *)

  val d_shallow : Prop.normal t -> unit
  (** Dump the toplevel prop *)

  val d_list : bool -> Prop.normal t list -> unit
  (** dump a joined prop list, the boolean indicates whether to print toplevel props only *)

  val free_vars : Prop.normal t -> Ident.t Sequence.t

  val filter : ('a t -> 'b option) -> 'a t list -> 'b list
  (** [jprop_filter filter joinedprops] applies [filter] to the elements
      of [joindeprops] and applies it to the subparts if the result is
      [None]. Returns the most absract results which pass [filter]. *)

  val jprop_sub : Sil.subst -> Prop.normal t -> Prop.exposed t
  (** apply a substitution to a jprop *)

  val map : ('a Prop.t -> 'b Prop.t) -> 'a t -> 'b t
  (** map the function to each prop in the jprop, pointwise *)

  val pp_list : Pp.env -> bool -> Format.formatter -> Prop.normal t list -> unit
  (** Print a list of joined props, the boolean indicates whether to print subcomponents of joined props *)

  val pp_short : Pp.env -> Format.formatter -> Prop.normal t -> unit
  (** Print the toplevel prop *)

  val to_prop : 'a t -> 'a Prop.t
  (** Extract the toplevel jprop of a prop *)
end

(** set of visited nodes: node id and list of lines of all the instructions *)
module Visitedset : Caml.Set.S with type elt = Procdesc.Node.id * int list

(** A spec consists of:
    pre: a joined prop
    posts: a list of props with path
    visited: a list of pairs (node_id, line) for the visited nodes *)
type 'a spec = {pre: 'a Jprop.t; posts: ('a Prop.t * Paths.Path.t) list; visited: Visitedset.t}

(** encapsulate type for normalized specs *)
module NormSpec : sig
  type t

  val erase_join_info_pre : Tenv.t -> t -> t
  (** Erase join info from pre of spec *)
end

(** Execution statistics *)
type stats =
  { stats_failure: SymOp.failure_kind option
        (** what type of failure stopped the analysis (if any) *)
  ; symops: int  (** Number of SymOp's throughout the whole analysis of the function *)
  ; mutable nodes_visited_fp: IntSet.t  (** Nodes visited during the footprint phase *)
  ; mutable nodes_visited_re: IntSet.t  (** Nodes visited during the re-execution phase *) }

(** Analysis status of the procedure:
    - Pending means that the summary has been created by the procedure has not been analyzed yet
    - Analyzed means that the analysis of the procedure is finished *)
type status = Pending | Analyzed

val equal_status : status -> status -> bool

val string_of_status : status -> string

type phase = FOOTPRINT | RE_EXECUTION

val equal_phase : phase -> phase -> bool

(** Payload: results of some analysis *)
type payload =
  { annot_map: AnnotReachabilityDomain.astate option
  ; buffer_overrun: BufferOverrunDomain.Summary.t option
  ; crashcontext_frame: Stacktree_t.stacktree option
  ; litho: LithoDomain.astate option
  ; preposts: NormSpec.t list option
  ; quandary: QuandarySummary.t option
  ; racerd: RacerDDomain.summary option
  ; resources: ResourceLeakDomain.summary option
  ; siof: SiofDomain.astate option
  ; typestate: unit TypeState.t option
  ; uninit: UninitDomain.summary option
  ; cost: CostDomain.summary option
  ; deadlock: DeadlockDomain.summary option }

(** Procedure summary *)
type summary =
  { phase: phase  (** in FOOTPRINT phase or in RE_EXECUTION PHASE *)
  ; payload: payload  (** payload containing the result of some analysis *)
  ; sessions: int ref  (** Session number: how many nodes went trough symbolic execution *)
  ; stats: stats  (** statistics: execution time and list of errors *)
  ; status: status  (** Analysis status of the procedure *)
  ; proc_desc: Procdesc.t }

val dummy : summary
(** dummy summary for testing *)

val add_summary : Typ.Procname.t -> summary -> unit
(** Add the summary to the table for the given function *)

val summary_exists_in_models : Typ.Procname.t -> bool
(** Check if a summary for a given procedure exists in the models directory *)

val clear_spec_tbl : unit -> unit
(** remove all the elements from the spec table *)

val d_spec : 'a spec -> unit
(** Dump a spec *)

val get_summary : Typ.Procname.t -> summary option
(** Return the summary option for the procedure name *)

val get_proc_name : summary -> Typ.Procname.t
(** Get the procedure name *)

val get_proc_desc : summary -> Procdesc.t

val get_attributes : summary -> ProcAttributes.t
(** Get the attributes of the procedure. *)

val get_formals : summary -> (Mangled.t * Typ.t) list
(** Get the formal parameters of the procedure *)

val get_phase : summary -> phase
(** Return the current phase for the proc *)

val get_err_log : summary -> Errlog.t

val get_loc : summary -> Location.t

val get_signature : summary -> string
(** Return the signature of a procedure declaration as a string *)

val get_specs_from_payload : summary -> Prop.normal spec list
(** Get the specs from the payload of the summary. *)

val get_summary_unsafe : string -> Typ.Procname.t -> summary
(** @deprecated Return the summary for the procedure name. Raises an exception when not found. *)

val get_status : summary -> status
(** Return the status (active v.s. inactive) of a procedure summary *)

val reset_summary : Procdesc.t -> summary
(** Reset a summary rebuilding the dependents and preserving the proc attributes if present. *)

val load_summary : DB.filename -> summary option
(** Load procedure summary from the given file *)

val normalized_specs_to_specs : NormSpec.t list -> Prop.normal spec list
(** Cast a list of normalized specs to a list of specs *)

val pp_spec : Pp.env -> (int * int) option -> Format.formatter -> Prop.normal spec -> unit
(** Print the spec *)

val pp_summary_html : SourceFile.t -> Pp.color -> Format.formatter -> summary -> unit
(** Print the summary in html format *)

val pp_summary_text : Format.formatter -> summary -> unit
(** Print the summary in text format *)

val pdesc_resolve_attributes : Procdesc.t -> ProcAttributes.t
(** Like proc_resolve_attributes but start from a proc_desc. *)

val proc_resolve_attributes : Typ.Procname.t -> ProcAttributes.t option
(** Try to find the attributes for a defined proc.
    First look at specs (to get attributes computed by analysis)
    then look at the attributes table.
    If no attributes can be found, return None.
*)

val proc_is_library : ProcAttributes.t -> bool
(** Check if the procedure is from a library:
    It's not defined, and there is no spec file for it. *)

val spec_normalize : Tenv.t -> Prop.normal spec -> NormSpec.t
(** Convert spec into normal form w.r.t. variable renaming *)

val store_summary : summary -> unit
(** Save summary for the procedure into the spec database *)
