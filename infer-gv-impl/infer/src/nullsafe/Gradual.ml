open! IStd

module N = struct
  type t = unit

  let pp f () = Format.pp_print_string f "()"

  let equal () () = true
end

module Lattice = AbstractDomain.Flat (N)

module GLattice = struct
  type t =
    | B (* \bottom *)
    | N (* N *)
    | T (* \top *)
    | Q (* {?} *)

  type unflat = Unknown | Known of Lattice.t

  let of_flat x =
    match x with
    | B -> Known Lattice.bottom
    | N -> Known (Lattice.v ())
    | T -> Known Lattice.top
    | Q -> Unknown

  let to_flat x =
    match x with
    | Unknown -> Q
    | Known l ->
      if Lattice.is_bottom l then B else
      if Lattice.is_top l then T else
      N

  let (<=) ~lhs:g1 ~rhs:g2 =
    match of_flat g1, of_flat g2 with
    | Unknown, _
    | _, Unknown ->
      true
    | Known l1, Known l2 ->
      Lattice.(<=) ~lhs:l1 ~rhs:l2

  let join g1 g2 =
    to_flat (match of_flat g1, of_flat g2 with
    | Unknown, Unknown ->
      Unknown
    | Unknown, Known l
    | Known l, Unknown ->
      if Lattice.is_top l then Known l else Unknown
    | Known l1, Known l2 ->
      Known (Lattice.join l1 l2))

  let widen ~prev ~next ~num_iters = Q

  let pp f g =
    match of_flat g with
    | Known l -> Lattice.pp f l
    | Unknown -> Format.pp_print_string f "?"
end

module Domain = AbstractDomain.Map (Var) (GLattice)

let is_this var =
  match Var.get_pvar var with
  | Some pvar -> Pvar.is_this pvar
  | _ -> false

let is_return var =
  match Var.get_pvar var with
  | Some pvar -> Pvar.is_return pvar
  | _ -> false

let args_annot procname =
  match Summary.proc_resolve_attributes procname with
  | Some { method_annotation = { params } } ->
    List.map params ~f:(fun annot ->
      if Config.gradual_unannotated then GLattice.N else
      if Annotations.ia_is_nonnull annot then GLattice.N else
      if Annotations.ia_is_nullable annot then GLattice.T else
      GLattice.Q
    )
  | _ ->
    []

module TransferFunctions (CFG : ProcCfg.S) = struct
  module CFG = CFG
  module Domain = Domain

  type extras = Summary.t

  let pp_session_name _ _ = ()

  module Vars = Caml.Set.Make(Var)

  type checked = { assume : Vars.t; deny: Vars.t }

  type param = { arg : HilExp.t; annot: GLattice.t }

  type proc_info = { args : param list; l : GLattice.t }

  let exec_instr astate { ProcData.pdesc; tenv; extras } _ (instr : HilInstr.t) =
    let summary = extras
    in
    match instr with
    | Metadata _ ->
      astate
    | Assign (_, _, loc)
    | Assume (_, _, _, loc)
    | Call (_, _, _, _, loc) ->
      let checks = ref []
      in
      let boundaries = ref []
      in
      let statics = ref []
      in
      let derefs = ref []
      in
      let check msg =
        if not Config.gradual_dereferences then
        checks := msg :: !checks
      in
      let bound msg =
        if not Config.gradual_dereferences then
        boundaries := msg :: !boundaries
      in
      let static msg =
        if not Config.gradual_dereferences then
        statics := msg :: !statics
      in
      let deref msg =
        if Config.gradual_dereferences then
        derefs := msg :: !derefs
      in
      let report_checks () =
        let msgs = List.rev !checks in
        if msgs <> [] then
        let trace = List.map msgs ~f:(fun msg ->
          Errlog.make_trace_element 1 loc msg []
        ) in
        Reporting.log_warning summary ~loc ~ltr:trace
          IssueType.gradual_check (String.concat ~sep:"," msgs)
      in
      let report_boundaries () =
        let msgs = List.rev !boundaries in
        if msgs <> [] then
        let trace = List.map msgs ~f:(fun msg ->
          Errlog.make_trace_element 1 loc msg []
        ) in
        Reporting.log_warning summary ~loc ~ltr:trace
          IssueType.gradual_boundary (String.concat ~sep:"," msgs)
      in
      let report_statics () =
        let msgs = List.rev !statics in
        if msgs <> [] then
        let trace = List.map msgs ~f:(fun msg ->
          Errlog.make_trace_element 1 loc msg []
        ) in
        Reporting.log_error summary ~loc ~ltr:trace
          IssueType.gradual_static (String.concat ~sep:"," msgs)
      in
      let report_derefs () =
        let msgs = List.rev !derefs in
        if msgs <> [] then
        let trace = List.map msgs ~f:(fun msg ->
          Errlog.make_trace_element 1 loc msg []
        ) in
        Reporting.log_warning summary ~loc ~ltr:trace
          IssueType.gradual_dereference (String.concat ~sep:"," msgs)
      in
      let report_all () =
        report_checks () ;
        report_boundaries () ;
        report_statics () ;
        report_derefs () ;
      in
      let field_annot fieldname =
        let struct_name = Typ.Name.Java.from_string (Typ.Fieldname.Java.get_class fieldname) in
        match Tenv.lookup tenv struct_name with
        | None ->
          GLattice.Q
        | Some struct_typ ->
          let nonnull = Annotations.field_has_annot fieldname struct_typ Annotations.ia_is_nonnull in
          let nullable = Annotations.field_has_annot fieldname struct_typ Annotations.ia_is_nullable in
          if Config.gradual_unannotated then GLattice.N else
          if nonnull then GLattice.N else
          if nullable then GLattice.T else
          GLattice.Q
      in
      (* https://stackoverflow.com/a/30519110/5044950 *)
      let contains_substring search target =
        String.substr_index search ~pattern:target <> None
      in
      let is_new procname : bool =
        contains_substring (Typ.Procname.get_method procname) "__new"
      in
      let proc_annot procname =
        let nonnull = Annotations.pname_has_return_annot
          procname
          ~attrs_of_pname:Summary.proc_resolve_attributes
          Annotations.ia_is_nonnull in
        let nullable = Annotations.pname_has_return_annot
          procname
          ~attrs_of_pname:Summary.proc_resolve_attributes
          Annotations.ia_is_nullable in
        if Config.gradual_unannotated then GLattice.N else
        if nonnull then GLattice.N else
        if nullable then GLattice.T else
        GLattice.Q
      in
      let rec combine args annots =
        match args with
        | [] ->
          []
        | arg :: args ->
          let annot, annots = (
            match annots with
            | [] -> (GLattice.Q, [])
            | annot :: annots -> (annot, annots)
          ) in
          { arg; annot } :: combine args annots
      in
      let rec check_chain (access : HilExp.AccessExpression.t) : GLattice.t =
        match access with
        | Base (var, _) ->
          if is_this var then GLattice.N
          else (
            match Domain.find_opt var astate with
            | None -> GLattice.Q
            | Some l -> l
          )
        | FieldOffset (sub, fieldname) ->
          ignore (check_chain sub) ;
          field_annot fieldname
        | ArrayOffset (sub, _, index) ->
          ignore (check_chain sub) ;
          (
            match index with
            | Some exp -> ignore (check_exp exp)
            | _ -> ()
          ) ;
          GLattice.Q
        | Dereference sub ->
          (
            let message = Format.asprintf "dereference of pointer `%a`"
              HilExp.AccessExpression.pp sub in
            deref message
          ) ;
          (
            match check_chain sub with
            | T ->
              let message = Format.asprintf "dereference of possibly-null pointer `%a`"
                HilExp.AccessExpression.pp sub in
              static message
            | Q ->
              let message = Format.asprintf "check dereference of ambiguous pointer `%a`"
                HilExp.AccessExpression.pp sub in
              check message
            | _ -> ()
          ) ;
          GLattice.N
        | _ ->
          GLattice.Q
      and check_exp (exp : HilExp.t) : GLattice.t =
        match exp with
        | AccessExpression access ->
          check_chain access
        | UnaryOperator (_, subexp, _)
        | Exception subexp
        | Sizeof (_, Some subexp) ->
          ignore (check_exp subexp) ;
          GLattice.N
        | BinaryOperator (_, left, right) ->
          ignore (check_exp left) ;
          ignore (check_exp right) ;
          GLattice.N
        | Cast (_, subexp) ->
          check_exp subexp
        | Constant _ when HilExp.is_null_literal exp ->
          GLattice.T
        | _ ->
          GLattice.N
      in
      let rec checked_vars (exp : HilExp.t) =
        match exp with
        | UnaryOperator
          ( LNot
          , ( BinaryOperator (Eq, AccessExpression (Base (var, _)), subexp)
            | BinaryOperator (Eq, subexp, AccessExpression (Base (var, _))) )
          , _ )
        | BinaryOperator (Ne, AccessExpression (Base (var, _)), subexp)
        | BinaryOperator (Ne, subexp, AccessExpression (Base (var, _)))
          when HilExp.is_null_literal subexp ->
          { assume = Vars.singleton var; deny = Vars.empty }
        | _ ->
          { assume = Vars.empty; deny = Vars.empty }
      in
      match instr with
      | Metadata _ -> astate (* should be unreachable *)
      | Assign (lhs, rhs, _) ->
        ignore (check_chain lhs) ;
        let l = check_exp rhs in
        let astate = (
          match lhs with
          | Base (var, _) ->
            let procname = (Procdesc.get_attributes pdesc).proc_name in
            (
              if not (GLattice.(<=) ~lhs:l ~rhs:(proc_annot procname)) then
              let message = Format.asprintf "possibly-null return in nonnull method `%s`"
                (Typ.Procname.to_string procname) in
              static message
            ) ;
            (
              match l, proc_annot procname with
              | Q, N ->
                let message = Format.asprintf "check ambiguous return in nonnull method `%s`"
                  (Typ.Procname.to_string procname) in
                bound message
              | _ -> ()
            ) ;
            Domain.add var l astate
          | FieldOffset (_, fieldname) ->
            (
              if not (GLattice.(<=) ~lhs:l ~rhs:(field_annot fieldname)) then
              let message = Format.asprintf "possibly-null assignment to nonnull field `%s`"
                (Typ.Fieldname.to_string fieldname) in
              static message
            ) ;
            (
              match l, field_annot fieldname with
              | Q, N ->
                let message = Format.asprintf "check ambiguous assignment to nonnull field `%s`"
                  (Typ.Fieldname.to_string fieldname) in
                bound message
              | _ -> ()
            ) ;
            astate
          | _ ->
            astate
        ) in
        report_all () ;
        astate
      | Assume (cond, _, _, _) ->
        ignore (check_exp cond) ;
        let astate = List.fold_left (Vars.elements (checked_vars cond).assume) ~init:astate
          ~f:(fun astate var -> Domain.add var GLattice.N astate)
        in
        report_all () ;
        astate
      | Call ((var, _), proc, args, _, _) ->
        let { args; l } = (
          match proc with
          | Direct procname when is_new procname ->
            let args = combine args (args_annot procname) in
            { args; l = GLattice.N }
          | Direct (Typ.Procname.Java procname as fullname) ->
            let annots = args_annot fullname in
            let combined = combine args annots in
            let l = proc_annot fullname in
            if Typ.Procname.Java.is_static procname
            then { args = combined; l }
            else (
              match args with
              | [] ->
                { args = combined; l }
              | receiver :: tail ->
                (
                  let message = Format.asprintf "method call on pointer `%a`"
                    HilExp.pp receiver in
                  deref message
                ) ;
                (
                  match check_exp receiver with
                  | T ->
                    let message = Format.asprintf "method call on possibly-null pointer `%a`"
                      HilExp.pp receiver in
                    static message
                  | Q ->
                    let message = Format.asprintf "check method call on ambiguous pointer `%a`"
                      HilExp.pp receiver in
                    check message
                  | _ -> ()
                ) ;
                { args = combine tail (args_annot fullname); l }
            )
          | Indirect access ->
            ignore (check_chain access) ;
            { args = combine args []; l = GLattice.Q }
          | _ ->
            { args = combine args []; l = GLattice.Q }
        ) in
        List.fold_left args ~init:() ~f:(fun _ { arg; annot } ->
          let arg_l = check_exp arg in
          (
            if not (GLattice.(<=) ~lhs:arg_l ~rhs:annot) then
            let message = Format.asprintf "possibly-null argument `%a` passed to nonnull parameter"
              HilExp.pp arg in
            static message
          ) ;
          (
            match arg_l, annot with
            | Q, N ->
              let message = Format.asprintf "check ambiguous argument `%a` passed to nonnull parameter"
                HilExp.pp arg in
              bound message
            | _ -> ()
          ) ;
        ) ;
        report_all () ;
        Domain.add var l astate
end

module Analyzer = LowerHil.MakeAbstractInterpreter (TransferFunctions (ProcCfg.Exceptional))

let checker { Callbacks.summary; proc_desc; tenv } =
  let rec combine params annots =
    match params, annots with
    | (param :: params), (annot :: annots) ->
      (param, annot) :: combine params annots
    | _ ->
      []
  in
  let attrs = Procdesc.get_attributes proc_desc in
  let params = List.filter_map attrs.formals ~f:(fun (name, _) ->
    let var = Var.of_pvar (Pvar.mk name attrs.proc_name) in
    if is_this var then None else Some var
  ) in
  let annots = args_annot attrs.proc_name in
  let params = combine params annots in
  let initial = List.fold_left params ~init:Domain.empty
    ~f:(fun astate (var, l) -> Domain.add var l astate) in
  let proc_data = ProcData.make proc_desc tenv summary in
  ignore (Analyzer.compute_post proc_data ~initial) ;
  summary
