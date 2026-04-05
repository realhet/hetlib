module het.firebird;  
version(/+$DIDE_REGION+/all) {
	enum ISC_STATUS : intptr_t
	{
		arg_end,
		arg_gds,
		arg_string,
		arg_cstring,
		arg_number,
		arg_interpreted,
		arg_vms,
		arg_unix,
		arg_domain,
		arg_dos,
		arg_mpexl,
		arg_mpexl_ipc,
		arg_next_mach =15,
		arg_netware,
		arg_win32,
		arg_warning,
		arg_sql_state,
		facility,
		base =335544320,
		arith_except,
		bad_dbkey,
		bad_db_format,
		bad_db_handle,
		bad_dpb_content,
		bad_dpb_form,
		bad_req_handle,
		bad_segstr_handle,
		bad_segstr_id,
		bad_tpb_content,
		bad_tpb_form,
		bad_trans_handle,
		bug_check,
		convert_error,
		db_corrupt,
		deadlock,
		excess_trans,
		from_no_match,
		infinap,
		infona,
		infunk,
		integ_fail,
		invalid_blr,
		io_error,
		lock_conflict,
		metadata_corrupt,
		not_valid,
		no_cur_rec,
		no_dup,
		no_finish,
		no_meta_update,
		no_priv,
		no_recon,
		no_record,
		no_segstr_close,
		obsolete_metadata,
		open_trans,
		port_len,
		read_only_field,
		read_only_rel,
		read_only_trans,
		read_only_view,
		req_no_trans,
		req_sync,
		req_wrong_db,
		segment,
		segstr_eof,
		segstr_no_op,
		segstr_no_read,
		segstr_no_trans,
		segstr_no_write,
		segstr_wrong_db,
		sys_request,
		stream_eof,
		unavailable,
		unres_rel,
		uns_ext,
		wish_list,
		wrong_ods,
		wronumarg,
		imp_exc,
		random,
		fatal_conflict,
		badblk,
		invpoolcl,
		nopoolids,
		relbadblk,
		blktoobig,
		bufexh,
		syntaxerr,
		bufinuse,
		bdbincon,
		reqinuse,
		badodsver,
		relnotdef,
		fldnotdef,
		dirtypage,
		waifortra,
		doubleloc,
		nodnotfnd,
		dupnodfnd,
		locnotmar,
		badpagtyp,
		corrupt,
		badpage,
		badindex,
		dbbnotzer,
		tranotzer,
		trareqmis,
		badhndcnt,
		wrotpbver,
		wroblrver,
		wrodpbver,
		blobnotsup,
		badrelation,
		nodetach,
		notremote,
		trainlim,
		notinlim,
		traoutsta,
		connect_reject,
		dbfile,
		orphan,
		no_lock_mgr,
		ctxinuse,
		ctxnotdef,
		datnotsup,
		badmsgnum,
		badparnum,
		virmemexh,
		blocking_signal,
		lockmanerr,
		journerr,
		keytoobig,
		nullsegkey,
		sqlerr,
		wrodynver,
		funnotdef,
		funmismat,
		bad_msg_vec,
		bad_detach,
		noargacc_read,
		noargacc_write,
		read_only,
		ext_err,
		non_updatable,
		no_rollback,
		bad_sec_info,
		invalid_sec_info,
		misc_interpreted,
		update_conflict,
		unlicensed,
		obj_in_use,
		nofilter,
		shadow_accessed,
		invalid_sdl,
		out_of_bounds,
		invalid_dimension,
		rec_in_limbo,
		shadow_missing,
		cant_validate,
		cant_start_journal,
		gennotdef,
		cant_start_logging,
		bad_segstr_type,
		foreign_key,
		high_minor,
		tra_state,
		trans_invalid,
		buf_invalid,
		indexnotdefined,
		login,
		invalid_bookmark,
		bad_lock_level,
		relation_lock,
		record_lock,
		max_idx,
		jrn_enable,
		old_failure,
		old_in_progress,
		old_no_space,
		no_wal_no_jrn,
		num_old_files,
		wal_file_open,
		bad_stmt_handle,
		wal_failure,
		walw_err,
		logh_small,
		logh_inv_version,
		logh_open_flag,
		logh_open_flag2,
		logh_diff_dbname,
		logf_unexpected_eof,
		logr_incomplete,
		logr_header_small,
		logb_small,
		wal_illegal_attach,
		wal_invalid_wpb,
		wal_err_rollover,
		no_wal,
		drop_wal,
		stream_not_defined,
		wal_subsys_error,
		wal_subsys_corrupt,
		no_archive,
		shutinprog,
		range_in_use,
		range_not_found,
		charset_not_found,
		lock_timeout,
		prcnotdef,
		prcmismat,
		wal_bugcheck,
		wal_cant_expand,
		codnotdef,
		xcpnotdef,
		except,
		cache_restart,
		bad_lock_handle,
		jrn_present,
		wal_err_rollover2,
		wal_err_logwrite,
		wal_err_jrn_comm,
		wal_err_expansion,
		wal_err_setup,
		wal_err_ww_sync,
		wal_err_ww_start,
		shutdown,
		existing_priv_mod,
		primary_key_ref,
		primary_key_notnull,
		ref_cnstrnt_notfound,
		foreign_key_notfound,
		ref_cnstrnt_update,
		check_cnstrnt_update,
		check_cnstrnt_del,
		integ_index_seg_del,
		integ_index_seg_mod,
		integ_index_del,
		integ_index_mod,
		check_trig_del,
		check_trig_update,
		cnstrnt_fld_del,
		cnstrnt_fld_rename,
		rel_cnstrnt_update,
		constaint_on_view,
		invld_cnstrnt_type,
		primary_key_exists,
		systrig_update,
		not_rel_owner,
		grant_obj_notfound,
		grant_fld_notfound,
		grant_nopriv,
		nonsql_security_rel,
		nonsql_security_fld,
		wal_cache_err,
		shutfail,
		check_constraint,
		bad_svc_handle,
		shutwarn,
		wrospbver,
		bad_spb_form,
		svcnotdef,
		no_jrn,
		transliteration_failed,
		start_cm_for_wal,
		wal_ovflow_log_required,
		text_subtype,
		dsql_error,
		dsql_command_err,
		dsql_constant_err,
		dsql_cursor_err,
		dsql_datatype_err,
		dsql_decl_err,
		dsql_cursor_update_err,
		dsql_cursor_open_err,
		dsql_cursor_close_err,
		dsql_field_err,
		dsql_internal_err,
		dsql_relation_err,
		dsql_procedure_err,
		dsql_request_err,
		dsql_sqlda_err,
		dsql_var_count_err,
		dsql_stmt_handle,
		dsql_function_err,
		dsql_blob_err,
		collation_not_found,
		collation_not_for_charset,
		dsql_dup_option,
		dsql_tran_err,
		dsql_invalid_array,
		dsql_max_arr_dim_exceeded,
		dsql_arr_range_error,
		dsql_trigger_err,
		dsql_subselect_err,
		dsql_crdb_prepare_err,
		specify_field_err,
		num_field_err,
		col_name_err,
		where_err,
		table_view_err,
		distinct_err,
		key_field_count_err,
		subquery_err,
		expression_eval_err,
		node_err,
		command_end_err,
		index_name,
		exception_name,
		field_name,
		token_err,
		union_err,
		dsql_construct_err,
		field_aggregate_err,
		field_ref_err,
		order_by_err,
		return_mode_err,
		extern_func_err,
		alias_conflict_err,
		procedure_conflict_error,
		relation_conflict_err,
		dsql_domain_err,
		idx_seg_err,
		node_name_err,
		table_name,
		proc_name,
		idx_create_err,
		wal_shadow_err,
		dependency,
		idx_key_err,
		dsql_file_length_err,
		dsql_shadow_number_err,
		dsql_token_unk_err,
		dsql_no_relation_alias,
		indexname,
		no_stream_plan,
		stream_twice,
		stream_not_found,
		collation_requires_text,
		dsql_domain_not_found,
		index_unused,
		dsql_self_join,
		stream_bof,
		stream_crack,
		db_or_file_exists,
		invalid_operator,
		conn_lost,
		bad_checksum,
		page_type_err,
		ext_readonly_err,
		sing_select_err,
		psw_attach,
		psw_start_trans,
		invalid_direction,
		dsql_var_conflict,
		dsql_no_blob_array,
		dsql_base_table,
		duplicate_base_table,
		view_alias,
		index_root_page_full,
		dsql_blob_type_unknown,
		req_max_clones_exceeded,
		dsql_duplicate_spec,
		unique_key_violation,
		srvr_version_too_old,
		drdb_completed_with_errs,
		dsql_procedure_use_err,
		dsql_count_mismatch,
		blob_idx_err,
		array_idx_err,
		key_field_err,
		no_delete,
		del_last_field,
		sort_err,
		sort_mem_err,
		version_err,
		inval_key_posn,
		no_segments_err,
		crrp_data_err,
		rec_size_err,
		dsql_field_ref,
		req_depth_exceeded,
		no_field_access,
		no_dbkey,
		jrn_format_err,
		jrn_file_full,
		dsql_open_cursor_request,
		ib_error,
		cache_redef,
		cache_too_small,
		log_redef,
		log_too_small,
		partition_too_small,
		partition_not_supp,
		log_length_spec,
		precision_err,
		scale_nogt,
		expec_short,
		expec_long,
		expec_ushort,
		escape_invalid,
		svcnoexe,
		net_lookup_err,
		service_unknown,
		host_unknown,
		grant_nopriv_on_base,
		dyn_fld_ambiguous,
		dsql_agg_ref_err,
		complex_view,
		unprepared_stmt,
		expec_positive,
		dsql_sqlda_value_err,
		invalid_array_id,
		extfile_uns_op,
		svc_in_use,
		err_stack_limit,
		invalid_key,
		net_init_error,
		loadlib_failure,
		network_error,
		net_connect_err,
		net_connect_listen_err,
		net_event_connect_err,
		net_event_listen_err,
		net_read_err,
		net_write_err,
		integ_index_deactivate,
		integ_deactivate_primary,
		cse_not_supported,
		tra_must_sweep,
		unsupported_network_drive,
		io_create_err,
		io_open_err,
		io_close_err,
		io_read_err,
		io_write_err,
		io_delete_err,
		io_access_err,
		udf_exception,
		lost_db_connection,
		no_write_user_priv,
		token_too_long,
		max_att_exceeded,
		login_same_as_role_name,
		reftable_requires_pk,
		usrname_too_long,
		password_too_long,
		usrname_required,
		password_required,
		bad_protocol,
		dup_usrname_found,
		usrname_not_found,
		error_adding_sec_record,
		error_modifying_sec_record,
		error_deleting_sec_record,
		error_updating_sec_db,
		sort_rec_size_err,
		bad_default_value,
		invalid_clause,
		too_many_handles,
		optimizer_blk_exc,
		invalid_string_constant,
		transitional_date,
		read_only_database,
		must_be_dialect_2_and_up,
		blob_filter_exception,
		exception_access_violation,
		exception_datatype_missalignment,
		exception_array_bounds_exceeded,
		exception_float_denormal_operand,
		exception_float_divide_by_zero,
		exception_float_inexact_result,
		exception_float_invalid_operand,
		exception_float_overflow,
		exception_float_stack_check,
		exception_float_underflow,
		exception_integer_divide_by_zero,
		exception_integer_overflow,
		exception_unknown,
		exception_stack_overflow,
		exception_sigsegv,
		exception_sigill,
		exception_sigbus,
		exception_sigfpe,
		ext_file_delete,
		ext_file_modify,
		adm_task_denied,
		extract_input_mismatch,
		insufficient_svc_privileges,
		file_in_use,
		service_att_err,
		ddl_not_allowed_by_db_sql_dial,
		cancelled,
		unexp_spb_form,
		sql_dialect_datatype_unsupport,
		svcnouser,
		depend_on_uncommitted_rel,
		svc_name_missing,
		too_many_contexts,
		datype_notsup,
		dialect_reset_warning,
		dialect_not_changed,
		database_create_failed,
		inv_dialect_specified,
		valid_db_dialects,
		sqlwarn,
		dtype_renamed,
		extern_func_dir_error,
		date_range_exceeded,
		inv_client_dialect_specified,
		valid_client_dialects,
		optimizer_between_err,
		service_not_supported,
		generator_name,
		udf_name,
		bad_limit_param,
		bad_skip_param,
		io_32bit_exceeded_err,
		invalid_savepoint,
		dsql_column_pos_err,
		dsql_agg_where_err,
		dsql_agg_group_err,
		dsql_agg_column_err,
		dsql_agg_having_err,
		dsql_agg_nested_err,
		exec_sql_invalid_arg,
		exec_sql_invalid_req,
		exec_sql_invalid_var,
		exec_sql_max_call_exceeded,
		conf_access_denied,
		wrong_backup_state,
		wal_backup_err,
		cursor_not_open,
		bad_shutdown_mode,
		concat_overflow,
		bad_substring_offset,
		foreign_key_target_doesnt_exist,
		foreign_key_references_present,
		no_update,
		cursor_already_open,
		stack_trace,
		ctx_var_not_found,
		ctx_namespace_invalid,
		ctx_too_big,
		ctx_bad_argument,
		identifier_too_long,
		except2,
		malformed_string,
		prc_out_param_mismatch,
		command_end_err2,
		partner_idx_incompat_type,
		bad_substring_length,
		charset_not_installed,
		collation_not_installed,
		att_shutdown,
		blobtoobig,
		must_have_phys_field,
		invalid_time_precision,
		blob_convert_error,
		array_convert_error,
		record_lock_not_supp,
		partner_idx_not_found,
		tra_num_exc,
		field_disappeared,
		met_wrong_gtt_scope,
		subtype_for_internal_use,
		illegal_prc_type,
		invalid_sort_datatype,
		collation_name,
		domain_name,
		domnotdef,
		array_max_dimensions,
		max_db_per_trans_allowed,
		bad_debug_format,
		bad_proc_BLR,
		key_too_big,
		concurrent_transaction,
		not_valid_for_var,
		not_valid_for,
		need_difference,
		long_login,
		fldnotdef2,
		invalid_similar_pattern,
		bad_teb_form,
		tpb_multiple_txn_isolation,
		tpb_reserv_before_table,
		tpb_multiple_spec,
		tpb_option_without_rc,
		tpb_conflicting_options,
		tpb_reserv_missing_tlen,
		tpb_reserv_long_tlen,
		tpb_reserv_missing_tname,
		tpb_reserv_corrup_tlen,
		tpb_reserv_null_tlen,
		tpb_reserv_relnotfound,
		tpb_reserv_baserelnotfound,
		tpb_missing_len,
		tpb_missing_value,
		tpb_corrupt_len,
		tpb_null_len,
		tpb_overflow_len,
		tpb_invalid_value,
		tpb_reserv_stronger_wng,
		tpb_reserv_stronger,
		tpb_reserv_max_recursion,
		tpb_reserv_virtualtbl,
		tpb_reserv_systbl,
		tpb_reserv_temptbl,
		tpb_readtxn_after_writelock,
		tpb_writelock_after_readtxn,
		time_range_exceeded,
		datetime_range_exceeded,
		string_truncation,
		blob_truncation,
		numeric_out_of_range,
		shutdown_timeout,
		att_handle_busy,
		bad_udf_freeit,
		eds_provider_not_found,
		eds_connection,
		eds_preprocess,
		eds_stmt_expected,
		eds_prm_name_expected,
		eds_unclosed_comment,
		eds_statement,
		eds_input_prm_mismatch,
		eds_output_prm_mismatch,
		eds_input_prm_not_set,
		too_big_blr,
		montabexh,
		modnotfound,
		nothing_to_cancel,
		ibutil_not_loaded,
		circular_computed,
		psw_db_error,
		invalid_type_datetime_op,
		onlycan_add_timetodate,
		onlycan_add_datetotime,
		onlycansub_tstampfromtstamp,
		onlyoneop_mustbe_tstamp,
		invalid_extractpart_time,
		invalid_extractpart_date,
		invalidarg_extract,
		sysf_argmustbe_exact,
		sysf_argmustbe_exact_or_fp,
		sysf_argviolates_uuidtype,
		sysf_argviolates_uuidlen,
		sysf_argviolates_uuidfmt,
		sysf_argviolates_guidigits,
		sysf_invalid_addpart_time,
		sysf_invalid_add_datetime,
		sysf_invalid_addpart_dtime,
		sysf_invalid_add_dtime_rc,
		sysf_invalid_diff_dtime,
		sysf_invalid_timediff,
		sysf_invalid_tstamptimediff,
		sysf_invalid_datetimediff,
		sysf_invalid_diffpart,
		sysf_argmustbe_positive,
		sysf_basemustbe_positive,
		sysf_argnmustbe_nonneg,
		sysf_argnmustbe_positive,
		sysf_invalid_zeropowneg,
		sysf_invalid_negpowfp,
		sysf_invalid_scale,
		sysf_argmustbe_nonneg,
		sysf_binuuid_mustbe_str,
		sysf_binuuid_wrongsize,
		missing_required_spb,
		net_server_shutdown,
		bad_conn_str,
		bad_epb_form,
		no_threads,
		net_event_connect_timeout,
		sysf_argmustbe_nonzero,
		sysf_argmustbe_range_inc1_1,
		sysf_argmustbe_gteq_one,
		sysf_argmustbe_range_exc1_1,
		internal_rejected_params,
		sysf_fp_overflow,
		udf_fp_overflow,
		udf_fp_nan,
		instance_conflict,
		out_of_temp_space,
		eds_expl_tran_ctrl,
		no_trusted_spb,
		async_active =335545017,
		gfix_db_name =335740929,
		gfix_invalid_sw,
		gfix_incmp_sw =335740932,
		gfix_replay_req,
		gfix_pgbuf_req,
		gfix_val_req,
		gfix_pval_req,
		gfix_trn_req,
		gfix_full_req =335740940,
		gfix_usrname_req,
		gfix_pass_req,
		gfix_subs_name,
		gfix_wal_req,
		gfix_sec_req,
		gfix_nval_req,
		gfix_type_shut,
		gfix_retry,
		gfix_retry_db =335740951,
		gfix_exceed_max =335740991,
		gfix_corrupt_pool,
		gfix_mem_exhausted,
		gfix_bad_pool,
		gfix_trn_not_valid,
		gfix_unexp_eoi =335741012,
		gfix_recon_fail =335741018,
		gfix_trn_unknown =335741036,
		gfix_mode_req =335741038,
		gfix_pzval_req =335741042,
		dsql_dbkey_from_non_table =336003074,
		dsql_transitional_numeric,
		dsql_dialect_warning_expr,
		sql_db_dialect_dtype_unsupport,
		isc_sql_dialect_conflict_num =336003079,
		dsql_warning_number_ambiguous,
		dsql_warning_number_ambiguous1,
		dsql_warn_precision_ambiguous,
		dsql_warn_precision_ambiguous1,
		dsql_warn_precision_ambiguous2,
		dsql_ambiguous_field_name,
		dsql_udf_return_pos_err,
		dsql_invalid_label,
		dsql_datatypes_not_comparable,
		dsql_cursor_invalid,
		dsql_cursor_redefined,
		dsql_cursor_not_found,
		dsql_cursor_exists,
		dsql_cursor_rel_ambiguous,
		dsql_cursor_rel_not_found,
		dsql_cursor_not_open,
		dsql_type_not_supp_ext_tab,
		dsql_feature_not_supported_ods,
		primary_key_required,
		upd_ins_doesnt_match_pk,
		upd_ins_doesnt_match_matching,
		upd_ins_with_complex_view,
		dsql_incompatible_trigger_type,
		dsql_db_trigger_type_cant_change,
		dyn_dup_table =336068740,
		dyn_column_does_not_exist =336068784,
		dyn_role_does_not_exist =336068796,
		dyn_no_grant_admin_opt,
		dyn_user_not_role_member,
		dyn_delete_role_failed,
		dyn_grant_role_to_user,
		dyn_inv_sql_role_name,
		dyn_dup_sql_role,
		dyn_kywd_spec_for_role,
		dyn_roles_not_supported,
		dyn_domain_name_exists =336068812,
		dyn_field_name_exists,
		dyn_dependency_exists,
		dyn_dtype_invalid,
		dyn_char_fld_too_small,
		dyn_invalid_dtype_conversion,
		dyn_dtype_conv_invalid,
		dyn_zero_len_id =336068820,
		max_coll_per_charset =336068829,
		invalid_coll_attr,
		dyn_wrong_gtt_scope =336068840,
		dyn_scale_too_big =336068852,
		dyn_precision_too_small,
		dyn_miss_priv_warning =336068855,
		dyn_ods_not_supp_feature,
		dyn_cannot_addrem_computed,
		dyn_no_empty_pw,
		dyn_dup_index,
		gbak_unknown_switch =336330753,
		gbak_page_size_missing,
		gbak_page_size_toobig,
		gbak_redir_ouput_missing,
		gbak_switches_conflict,
		gbak_unknown_device,
		gbak_no_protection,
		gbak_page_size_not_allowed,
		gbak_multi_source_dest,
		gbak_filename_missing,
		gbak_dup_inout_names,
		gbak_inv_page_size,
		gbak_db_specified,
		gbak_db_exists,
		gbak_unk_device,
		gbak_blob_info_failed =336330772,
		gbak_unk_blob_item,
		gbak_get_seg_failed,
		gbak_close_blob_failed,
		gbak_open_blob_failed,
		gbak_put_blr_gen_id_failed,
		gbak_unk_type,
		gbak_comp_req_failed,
		gbak_start_req_failed,
		gbak_rec_failed,
		gbak_rel_req_failed,
		gbak_db_info_failed,
		gbak_no_db_desc,
		gbak_db_create_failed,
		gbak_decomp_len_error,
		gbak_tbl_missing,
		gbak_blob_col_missing,
		gbak_create_blob_failed,
		gbak_put_seg_failed,
		gbak_rec_len_exp,
		gbak_inv_rec_len,
		gbak_exp_data_type,
		gbak_gen_id_failed,
		gbak_unk_rec_type,
		gbak_inv_bkup_ver,
		gbak_missing_bkup_desc,
		gbak_string_trunc,
		gbak_cant_rest_record,
		gbak_send_failed,
		gbak_no_tbl_name,
		gbak_unexp_eof,
		gbak_db_format_too_old,
		gbak_inv_array_dim,
		gbak_xdr_len_expected =336330807,
		gbak_open_bkup_error =336330817,
		gbak_open_error,
		gbak_missing_block_fac =336330934,
		gbak_inv_block_fac,
		gbak_block_fac_specified,
		gbak_missing_username =336330940,
		gbak_missing_password,
		gbak_missing_skipped_bytes =336330952,
		gbak_inv_skipped_bytes,
		gbak_err_restore_charset =336330965,
		gbak_err_restore_collation =336330967,
		gbak_read_error =336330972,
		gbak_write_error,
		gbak_db_in_use =336330985,
		gbak_sysmemex =336330990,
		gbak_restore_role_failed =336331002,
		gbak_role_op_missing =336331005,
		gbak_page_buffers_missing =336331010,
		gbak_page_buffers_wrong_param,
		gbak_page_buffers_restore,
		gbak_inv_size =336331014,
		gbak_file_outof_sequence,
		gbak_join_file_missing,
		gbak_stdin_not_supptd,
		gbak_stdout_not_supptd,
		gbak_bkup_corrupt,
		gbak_unk_db_file_spec,
		gbak_hdr_write_failed,
		gbak_disk_space_ex,
		gbak_size_lt_min,
		gbak_svc_name_missing =336331025,
		gbak_not_ownr,
		gbak_mode_req =336331031,
		gbak_just_data =336331033,
		gbak_data_only,
		gbak_invalid_metadata =336331093,
		gbak_invalid_data,
		dsql_too_old_ods =336397205,
		dsql_table_not_found,
		dsql_view_not_found,
		dsql_line_col_error,
		dsql_unknown_pos,
		dsql_no_dup_name,
		dsql_too_many_values,
		dsql_no_array_computed,
		dsql_implicit_domain_name,
		dsql_only_can_subscript_array,
		dsql_max_sort_items,
		dsql_max_group_items,
		dsql_conflicting_sort_field,
		dsql_derived_table_more_columns,
		dsql_derived_table_less_columns,
		dsql_derived_field_unnamed,
		dsql_derived_field_dup_name,
		dsql_derived_alias_select,
		dsql_derived_alias_field,
		dsql_auto_field_bad_pos,
		dsql_cte_wrong_reference,
		dsql_cte_cycle,
		dsql_cte_outer_join,
		dsql_cte_mult_references,
		dsql_cte_not_a_union,
		dsql_cte_nonrecurs_after_recurs,
		dsql_cte_wrong_clause,
		dsql_cte_union_all,
		dsql_cte_miss_nonrecursive,
		dsql_cte_nested_with,
		dsql_col_more_than_once_using,
		dsql_unsupp_feature_dialect,
		dsql_cte_not_used,
		dsql_col_more_than_once_view,
		dsql_unsupported_in_auto_trans,
		dsql_eval_unknode,
		dsql_agg_wrongarg,
		dsql_agg2_wrongarg,
		dsql_nodateortime_pm_string,
		dsql_invalid_datetime_subtract,
		dsql_invalid_dateortime_add,
		dsql_invalid_type_minus_date,
		dsql_nostring_addsub_dial3,
		dsql_invalid_type_addsub_dial3,
		dsql_invalid_type_multip_dial1,
		dsql_nostring_multip_dial3,
		dsql_invalid_type_multip_dial3,
		dsql_mustuse_numeric_div_dial1,
		dsql_nostring_div_dial3,
		dsql_invalid_type_div_dial3,
		dsql_nostring_neg_dial3,
		dsql_invalid_type_neg,
		dsql_max_distinct_items,
		gsec_cant_open_db =336723983,
		gsec_switches_error,
		gsec_no_op_spec,
		gsec_no_usr_name,
		gsec_err_add,
		gsec_err_modify,
		gsec_err_find_mod,
		gsec_err_rec_not_found,
		gsec_err_delete,
		gsec_err_find_del,
		gsec_err_find_disp =336723996,
		gsec_inv_param,
		gsec_op_specified,
		gsec_pw_specified,
		gsec_uid_specified,
		gsec_gid_specified,
		gsec_proj_specified,
		gsec_org_specified,
		gsec_fname_specified,
		gsec_mname_specified,
		gsec_lname_specified,
		gsec_inv_switch =336724008,
		gsec_amb_switch,
		gsec_no_op_specified,
		gsec_params_not_allowed,
		gsec_incompat_switch,
		gsec_inv_username =336724044,
		gsec_inv_pw_length,
		gsec_db_specified,
		gsec_db_admin_specified,
		gsec_db_admin_pw_specified,
		gsec_sql_role_specified,
		license_no_file =336789504,
		license_op_specified =336789523,
		license_op_missing,
		license_inv_switch,
		license_inv_switch_combo,
		license_inv_op_combo,
		license_amb_switch,
		license_inv_parameter,
		license_param_specified,
		license_param_req,
		license_syntx_error,
		license_dup_id =336789534,
		license_inv_id_key,
		license_err_remove,
		license_err_update,
		license_err_convert,
		license_err_unk,
		license_svc_err_add,
		license_svc_err_remove,
		license_eval_exists =336789563,
		gstat_unknown_switch =336920577,
		gstat_retry,
		gstat_wrong_ods,
		gstat_unexpected_eof,
		gstat_open_err =336920605,
		gstat_read_err,
		gstat_sysmemex,
		fbsvcmgr_bad_am =336986113,
		fbsvcmgr_bad_wm,
		fbsvcmgr_bad_rs,
		fbsvcmgr_info_err,
		fbsvcmgr_query_err,
		fbsvcmgr_switch_unknown,
		fbsvcmgr_bad_sm =336986159,
		fbsvcmgr_fp_open,
		fbsvcmgr_fp_read,
		fbsvcmgr_fp_empty,
		fbsvcmgr_bad_arg =336986164,
		utl_trusted_switch =337051649,
		err_max =964,
		
	} 
	mixin StaticAssertEQ!(q{hashOfEnum!ISC_STATUS}, q{6125316308050462486}); 
	import het, het.parser: CodeLocation; 
	
	/+
		Docs:
		
		Firebird 2.5 Language reference:
		/+Link: https://firebirdsql.org/file/documentation/html/en/refdocs/fblangref25/firebird-25-language-reference.html+/
		
		Firebird Internals:
		/+Link: https://www.firebirdsql.org/file/documentation/html/en/firebirddocs/firebirdinternals/firebird-internals.html+/
		
		Large Example project:
		/+Link: https://github.com/mariuz/flamerobin/tree/master+/
		
		Firebird 2.5 docs, Understanding transaction parameters
		/+Link: https://wiki.freepascal.org/Firebird#Firebird+/
		
		IS SQL_NULL input parameter handling - `? IS NULL` optimization:
		/+
			Link: https://firebirdsql.org/file/documentation/chunk/en/refdocs/fblangref25
			/fblangref25-datatypes-special.html
		+/
		
		Delphi Firebird API:
		/+Link: https://github.com/ccy/delphi-firebird-api/tree/master+/
	+/
	
	/+
		Summary (2026-03-12):
		- Added FbFields to manage XSQLDA metadata + field info.
		- XSQLVAR used directly for name/relation/owner/alias_, type, nullable, scale, subtype, len.
		- XSQLDA validate/describe/execute/fetch helpers wired; SQL_DIALECT_3 used for prepare/execute.
		- isc_dsql_describe/execute/fetch bindings added; fetch uses status==100 as EOF.
		- UTF8 client charset set in attach_database.
		- Data buffer prep aligns string data to 16 bytes, supports nullable indicators, and packs row buffers.
		
		Token usage: total=414,571 input=381,882 (+ 6,882,816 cached) output=32,689 (reasoning 6,912)
		To continue this session, run 
		/+Console: codex.cmd resume 019ce107-d061-7ab0-91e6-a4620ee55e23+/
		unicode support: chcp 65001
	+/
	alias fb = Singleton!FbFuncts; 
	
	private ubyte[] toPascalString(string s)
	=> s.length.to!ubyte ~ (cast(ubyte[])(s)); 
	private string fetchPascalString(ref ubyte[] raw)
	{
		if(raw.empty) return ""; 
		const 	desiredSize 	= raw[0],
			availableSize 	= .min(desiredSize, raw.length-1); 
		auto res = (cast(string)(raw[1..$][0..availableSize])); 
		raw = raw[1+availableSize..$]; 
		return res; 
	} 
	
	struct Varchar(size_t N)
	{
		static assert(mixin(界3(q{1},q{N},q{0x7FFF})), "Varchar maxLength out of range."); 
		
		private string value; 
		
		this(string s)
		{ this(s, false); }  this(string s, bool trim)
		{ set(s, trim); } 
		
		@property get() const => value; 
		void set(string s, bool trim=false)
		{
			if(value.length<=N) { value = s; }
			else {
				enforce(trim, i"String length ($(s.length)) is too long for Varchar!$(N).".text); 
				value = s[0..N]; 
			}
		} 
	} 
	
	struct Literal { string value; } 
	enum isLiteral(T) = is(T==Literal); 
	
	private alias intptr_t = long, uintptr_t = ulong; 
	
	enum ISC_STATUS_LENGTH = 20; 
	alias ISC_STATUS_ARRAY 	= ISC_STATUS[ISC_STATUS_LENGTH]; 
	
	enum  {
		FB_SQLSTATE_LENGTH 	= 5,
		FB_SQLSTATE_SIZE 	= FB_SQLSTATE_LENGTH + 1
	} 
	
	alias FB_SQLSTATE_STRING = char[FB_SQLSTATE_SIZE]; 
	
	alias ISC_SCHAR 	= byte,
	ISC_UCHAR 	= ubyte,
	ISC_SHORT 	= short,
	ISC_USHORT 	= ushort,
	ISC_LONG = uint, 
	ISC_ULONG = int,
	ISC_INT64 	= long,
	ISC_UINT64 	= ulong; 
	
	version(none /+Note: This is in het.package.d, integrated with DateTime.+/)
	{
		alias ISC_DATE 	= Typedef!(uint, 0, "ISC_DATE"), 
		ISC_TIME 	= Typedef!(uint, 0, "ISC_TIME"); struct ISC_TIMESTAMP {
			ISC_DATE date; 
			ISC_TIME time; 
		} 
	}
	
	struct ISC_QUAD { ISC_LONG high; 	ISC_ULONG low; } 
	struct ISC_BLOB { ISC_LONG high; 	ISC_ULONG low; } 
	struct ISC_ARRAY { ISC_LONG high; 	ISC_ULONG low; } 
	
	alias isc_db_handle 	= Typedef!(uint, 0, "isc_db_handle"),
	isc_tr_handle 	= Typedef!(uint, 0, "isc_tr_handle"),
	isc_stmt_handle 	= Typedef!(uint, 0, "isc_stmt_handle"); 
	
	enum :ubyte { DSQL_close = 1, DSQL_drop = 2, DSQL_unprepare = 4 } 
	
	alias SQL_DIALECT = Typedef!(ISC_SHORT, 0, "SQL_DIALECT"); 
	enum SQL_DIALECT_3 = SQL_DIALECT(3); 
	
	enum SQL_TYPE:ushort
	{
		TEXT	= 452,
		VARYING	= 448,
		SHORT	= 500,
		LONG	= 496,
		FLOAT	= 482,
		DOUBLE	= 480,
		D_FLOAT	= 530,
		TIMESTAMP	= 510,
		BLOB	= 520,
		ARRAY	= 540,
		QUAD	= 550,
		TIME	= 560,
		DATE	= 570,
		INT64	= 580,
		NULL	= 32766
	} 
	
	alias DA_VERSION = Typedef!(ISC_SHORT, 0, "DA_VERSION"); 
	enum SQLDA_VERSION1 = DA_VERSION(1); 
	
	struct XSQLDA
	{
		DA_VERSION version_; 
		char[8] sqldaid=0; 
		ISC_LONG sqldabc; 
		ISC_SHORT sqln; 
		ISC_SHORT sqld; 
		XSQLVAR[1] sqlvar; 
	} 
	
	size_t XSQLDA_LENGTH(int n)
	=> (XSQLDA.sizeof + (n - 1) * XSQLVAR.sizeof); 
	
	struct XSQLVAR
	{
		ISC_SHORT sqltype, sqlscale, sqlsubtype, sqllen; 
		ubyte* sqldata; ISC_SHORT* sqlind; 
		
		mixin template ISC_STRING(string name, ISC_SHORT size)
		{
			mixin(iq{
				private
				{ ISC_SHORT $(name)_len; char[$(size)] $(name)_buf=0; } 
				@property $(name)() const
				=> $(name)_buf[0..$(name)_len.clamp(0, $(size))].to!string; 
				@property void $(name)(string s)
				{
					$(name)_len = (cast(ISC_SHORT)(s.length.min($(size)))); 
					$(name)_buf[0..$(name)_len] = s[0..$(name)_len]; 
					$(name)_buf[$(name)_len..$(size)] = '\0'; 
				} 
			}.text); 
		} 
		
		mixin ISC_STRING!(q{sqlName}, 32); 
		mixin ISC_STRING!(q{relName}, 32); 
		mixin ISC_STRING!(q{ownName}, 32); 
		mixin ISC_STRING!(q{aliasName}, 32); 
		
		bool isNullable() const => sqltype & 1; 
		bool isNull() const => isNullable && sqlind && *sqlind || !sqldata; 
		string toString() const => toPlainText; 
		
		SQL_TYPE type() const => (sqltype & ~1).to!SQL_TYPE; 
		
		bool isSomeNumber() const
		{
			with(SQL_TYPE)
			return !!type.among(
				SHORT, LONG, INT64, 
				FLOAT, DOUBLE, D_FLOAT
			); 
		} 
		
		string toPlainText() const
		{
			if(isNull) return "null"; 
			
			static string formatScaled(T)(T v, short scale)
			{
				if(scale == 0) return v.to!string; 
				if(scale > 0) return v.to!string ~ "0".replicate(scale); 
				const neg = v < 0, frac = -scale; 
				auto s = abs(v).to!string; 
				if(s.length <= frac)
				s = "0".replicate(frac - s.length + 1) ~ s; 
				const p = s.length - frac; 
				return ((neg)?("-"):("")) ~ s[0 .. p] ~ "." ~ s[p .. $]; 
			} 
			
			auto date_() => Date(*(cast(ISC_DATE*)(sqldata))).text; 
			auto time_(int ofs=0) => iscTimeToStr(*(cast(ISC_TIME*)(sqldata+ofs)), 2, 6); 
			auto quad(string prefix)
			{ with(*(cast(ISC_QUAD*)(sqldata))) return i"$(prefix)($(high):$(low))".text; } 
			with(SQL_TYPE)
			final switch(type)
			{
				case VARYING: 	return (cast(immutable(char)*)(sqldata+2))
				[
					0 .. (*(cast(short*)(sqldata)))
						.min(sqllen).clamp(0, 0x7fff)
				].dup; 
				case TEXT: 	return (cast(immutable(char)*)(sqldata))
					.toStr(sqllen.clamp(0, 0x7fff)).dup
					.stripRight; 
				case SHORT: 	return formatScaled(*(cast(short*)(sqldata)), sqlscale); 
				case LONG: 	return formatScaled(*(cast(int*)(sqldata)), sqlscale); 
				case INT64: 	return formatScaled(*(cast(long*)(sqldata)), sqlscale); 
				case FLOAT: 	return format!"%.8g"(*(cast(float*)(sqldata))); 
				case DOUBLE: 	return format!"%.16g"(*(cast(double*)(sqldata))); 
				case DATE: 	return date_; 
				case TIME: 	return time_; 
				case TIMESTAMP: 	return date_ ~ ' ' ~ time_(4); 
				case QUAD, 
				BLOB, ARRAY: 	return quad("ISC_"~type.text); 
				case 	D_FLOAT,
					NULL: 	return "UNSUPPORTED_"~type.text; 
			}
		} 
		
		string toJsonText() const
		{
			if(isNull) return "null"; 
			with(SQL_TYPE)
			switch(type)
			{
				case 	VARYING, 
					TEXT,
					DATE: 	return toPlainText.quoted; 
				case TIME: 	return iq{$((*(cast(uint*)(sqldata))*0.0001).format!"%.4f")}.text; 
				case TIMESTAMP: 	return DateTime(Local, *(cast(ISC_TIMESTAMP*)(sqldata)))
				.utcTimestamp.withEnding('Z').quoted
				/+
					Todo: 1 digit precision loss from Firebird.
					SYSTEMTIME.wMilliseconds has 3 digits only.
				+/; 
				default: 	return toPlainText; 
			}
		} 
		
		string tableIdentifier(sizediff_t idx=-1, string id = "Table")
		=> relName.sanitizeDLangTypeIdentifier(id, idx).singularize; 
		
		string fieldIdentifier(sizediff_t idx=-1, string id = "field")
		=> aliasName.sanitizeDLangFieldIdentifier(id, idx); 
		
		string baseDType() const
		{
			string sc(string t)() => ((sqlscale)?("double"):(t)); 
			with(SQL_TYPE)
			return type.predSwitch
			(
				SQL_TYPE.VARYING, 	"string",
				SQL_TYPE.TEXT, 	"string",
				SQL_TYPE.SHORT, 	sc!"short",
				SQL_TYPE.LONG, 	sc!"int",
				SQL_TYPE.INT64, 	sc!"long",
				SQL_TYPE.FLOAT, 	"float",
				SQL_TYPE.DOUBLE, 	"double",
				SQL_TYPE.DATE, 	"Date",
				SQL_TYPE.TIMESTAMP, 	"DateTime",
				SQL_TYPE.TIME, 	"Time",
					
				/+anything else:+/	"ISC_"~type.text
			); 
		} 
		
		string DType() const
		{ auto t = baseDType; if(isNullable) t = "Nullable!("~t~")"; return t; } 
		
		string baseDLiteral() const
		{
			auto d() => Date(*(cast(ISC_DATE*)(sqldata))).text
				.splitter('.').map!((a)=>(a.withoutStarting('0'))); 
			auto t(int ofs=0) => iscTimeToStr(*(cast(ISC_TIME*)(sqldata+ofs)), 2, 6)
				.splitter(':').map!((a)=>(a.withoutStarting('0'))); 
			with(SQL_TYPE)
			switch(type)
			{
				case 	VARYING, 
					TEXT: 	return toPlainText.quoted; 
				case SHORT: 	return "short("~toPlainText~")"; 
				case 	LONG, 
				INT64, DOUBLE: 	return toPlainText; 
				case FLOAT: 	return toPlainText~"f"; 
				case DATE: 	return iq{Date($(d.join(", ")))}.text; 
				case TIME: 	return iq{toTime($(t.join(", ")))}.text; 
				case TIMESTAMP: 	return iq{DateTime($(chain(d, t(4)).join(", ")))}.text; 
				case QUAD, 
				BLOB, ARRAY: 	return toPlainText; 
				default: 	return "UNSUPPORTED_DLiteral_"~type.text; 
			}
			
		} 
		
		string DLiteral() const
		=> /+((isNullable && isNull)?(iq{Nullable!($(baseDType)).init}.text):(baseDLiteral))+/
		((isNullable)?(((isNull)?(iq{$(DType).init}.text) :(iq{$(DType)($(baseDLiteral))}.text))) :(baseDLiteral)); 
		
		FT to(FT)() => readValue!FT; 
		FT readValue(FT)()
		{
			auto loc() => i"readValue!$(FT.stringof) Error:  [$(relName)].[$(aliasName)]: ".text; 
			auto convError(string type="")()
			{ enforce(0, loc ~ i"Unhandled $(type) conversion: $(type.text) -> $(FT.stringof)".text); } 
			
			static if(is(FT == Nullable!NT, NT))
			{
				if(isNull)	return Nullable!NT.init; 
				else	return Nullable!NT(readValue!NT); 
				/+Todo: Is the target is NOT Nullable: For floats, nan could be used. For strings: ""+/
			}
			else
			{
				if(isNull) enforce(0, loc ~ i"Null recieved but field is not nullable.".text); 
				static if(is(FT == string))	{ return toPlainText; }
				else static if(is(FT == Date))	{ return Date(*(cast(ISC_DATE*)(sqldata))); }
				else static if(is(FT == Time))	{ return iscTimeToTime(*(cast(ISC_TIME*)(sqldata))); }
				else static if(is(FT == DateTime))	{ return DateTime(Local, *(cast(ISC_TIMESTAMP*)(sqldata))); }
				else static if(isIntegral!FT)
				{
					auto scale(T)(T* a)
					{ if(sqlscale) convError!"scaled numeric to integer"; return (cast(FT)(*a)); } 
					with(SQL_TYPE)
					switch(type)
					{
						case SHORT: 	return scale((cast(short*)(sqldata))); 
						case LONG: 	return scale((cast(int*)(sqldata))); 
						case INT64: 	return scale((cast(long*)(sqldata))); 
						default: 	convError!"integer"; 
					}
				}
				else static if(isFloatingPoint!FT)
				{
					with(SQL_TYPE)
					switch(type)
					{
						case FLOAT: 	return (cast(FT)(*(cast(float*)(sqldata)))); 
						case DOUBLE: 	return (cast(FT)(*(cast(double*)(sqldata)))); 
						case SHORT: 	return (cast(FT)(*(cast(short*)(sqldata)) * pow(10.0, sqlscale))); 
						case LONG: 	return (cast(FT)(*(cast(int*)(sqldata)) * pow(10.0, sqlscale))); 
						case INT64: 	return (cast(FT)(*(cast(long*)(sqldata)) * pow(10.0, sqlscale))); 
						default: 	convError!"float"; 
					}
				}
				else static if(is(FT == bool))
				{
					with(SQL_TYPE)
					switch(type)
					{
						case SHORT: 	return !!*(cast(short*)(sqldata)); 
						case LONG: 	return !!*(cast(int*)(sqldata)); 
						case INT64: 	return !!*(cast(long*)(sqldata)); 
						default: 	convError!"bool"; 
					}
				}
				else static assert(0, "Unhandled field type: " ~ FT.stringof); 
			}
			convError!"type"; assert(0); 
		} 
	} 
	
	version(/+$DIDE_REGION+/all) {
		string convertTokenStringToSQL(string input)
		{
			string output; void put(T)(T s) { output~=s; } 
			char peek() => input.get(0, '\0'); 
			char[2] peek2() => [peek, input.get(1, '\0')]; 
			void skip(size_t n=1) { input = input[min(n, $)..$]; } 
			void transfer(size_t n=1) { put(input[0..min(n, $)]); skip(n); } 
			bool loop() => !input.empty; 
			void transferDStr()
			{ while(loop && peek!='`') { if(peek=='\'') put('\''); transfer; }} 
			void transferCStr()
			{ while(loop && peek!='"') { transfer; }} 
			void transferLineCmt()
			{
				while(loop) {
					if(peek=='\r') { transfer((peek2=="\r\n")?(2):(1)); break; }
					if(peek=='\n') { transfer; break; }
					transfer; 
				}
			} 
			void transferCCmt()
			{ while(loop) { if(peek2==`*/`) { break; }transfer; }} 
			void transferDCmt()
			{
				int level=1; 
				while(loop) {
					if(peek2==`*/`) { skip(2); put(`x/`); continue; }
					if(peek2==`/*`) { skip(2); put(`/x`); continue; }
					if(peek2==`/+`) { ++level; transfer(2); continue; }
					if(peek2==`+/`) { if(!--level) break; transfer(2); continue; }
					transfer; 
				}
			} 
			
			while(loop)
			{
				if(peek=='`') { skip; put('\''); transferDStr; skip; put('\''); continue; }
				if(peek=='"') { skip; put('"'); transferCStr; skip; put('"'); continue; }
				if(peek2==`//`) { skip(2); put(`--`); transferLineCmt; continue; }
				if(peek2==`/*`) { transfer(2); transferCCmt; transfer(2); continue; }
				if(peek2==`/+`) { skip(2); put("/*"); transferDCmt; skip(2); put("*/"); continue; }
				transfer; 
			}
			return output; 
		} 
		
		private bool test_convertTokenStringToSQL()
		{
			void test(string a, string b)
			{ enforce(a.convertTokenStringToSQL==b); } 
			
			// Test 1: Basic nested comment conversion
			test(
				q{/+ This is a comment +/},
				"/* This is a comment */"
			); 
			// Test 2: Nested comments with neutralization
			test(
				q{/+ Outer /* inner */ +/},
				"/* Outer /x inner x/ */"
			); 
			// Test 3: Backtick string conversion
			test(
				q{`SELECT 'O''Reilly' FROM users`},
				"'SELECT ''O''''Reilly'' FROM users'"
			); 
			// Test 4: Line comment conversion
			test(
				"// This is a line comment\ncode",
				"-- This is a line comment\ncode"
			); 
			// Test 5: No conversion in double quotes
			test(
				q{"`not converted`"},
				"\"`not converted`\""
			); 
			// Test 6: Complex mixed content
			test(
				`/+ Outer comment
	"SELECT * blah = 'O''Reilly'" //cmt
+/`,
				`/* Outer comment
	"SELECT * blah = 'O''Reilly'" //cmt
*/`
			); 
			// Test 7: Escaped backticks
			test(
				"`String with \\` backtick`", 
				"'String with \\' backtick''"
			); 
			// Test 8: Nested /+ +/ at multiple levels
			test(
				"/+ Level1 /+ Level2 +/ Level1 end +/", 
				"/* Level1 /+ Level2 +/ Level1 end */"
			); 
			return true; 
		} 
		static assert(test_convertTokenStringToSQL); 
	}
	
	//Transaction parameter block constants
	enum isc_tpb_ : ubyte
	{
		version1	= 1,
		version3	= 3,
		consistency	= 1,
		concurrency	= 2,
		shared_	= 3,
		protected_	= 4,
		exclusive	= 5,
		wait	= 6,
		nowait	= 7,
		read	= 8,
		write	= 9,
		lock_read	= 10,
		lock_write	= 11,
		verb_time	= 12,
		commit_time	= 13,
		ignore_limbo	= 14,
		read_committed	= 15,
		autocommit	= 16,
		rec_version	= 17,
		no_rec_version	= 18,
		restart_requests	= 19,
		no_auto_undo	= 20,
		lock_timeout	= 21
	} 
	
	//Database parameter block constants
	enum isc_dpb_ : ubyte
	{
		version1	= 1,
		cdd_pathname	= 1,
		allocation	= 2,
		journal	= 3,
		page_size	= 4,
		num_buffers	= 5,
		buffer_length	= 6,
		debug_	= 7,
		garbage_collect	= 8,
		verify	= 9,
		sweep	= 10,
		enable_journal	= 11,
		disable_journal	= 12,
		dbkey_scope	= 13,
		number_of_users	= 14,
		trace	= 15,
		no_garbage_collect	= 16,
		damaged	= 17,
		license	= 18,
		sys_user_name	= 19,
		encrypt_key	= 20,
		activate_shadow	= 21,
		sweep_interval	= 22,
		delete_shadow	= 23,
		force_write	= 24,
		begin_log	= 25,
		quit_log	= 26,
		no_reserve	= 27,
		user_name	= 28,
		password	= 29,
		password_enc	= 30,
		sys_user_name_enc	= 31,
		interp	= 32,
		online_dump	= 33,
		old_file_size	= 34,
		old_num_files	= 35,
		old_file	= 36,
		old_start_page	= 37,
		old_start_seqno	= 38,
		old_start_file	= 39,
		drop_walfile	= 40,
		old_dump_id	= 41,
		wal_backup_dir	= 42,
		wal_chkptlen	= 43,
		wal_numbufs	= 44,
		wal_bufsize	= 45,
		wal_grp_cmt_wait	= 46,
		lc_messages	= 47,
		lc_ctype	= 48,
		cache_manager	= 49,
		shutdown	= 50,
		online	= 51,
		shutdown_delay	= 52,
		reserved	= 53,
		overwrite	= 54,
		sec_attach	= 55,
		disable_wal	= 56,
		connect_timeout	= 57,
		dummy_packet_interval	= 58,
		gbak_attach	= 59,
		sql_role_name	= 60,
		set_page_buffers	= 61,
		working_directory	= 62,
		sql_dialect	= 63,
		set_db_readonly	= 64,
		set_db_sql_dialect	= 65,
		gfix_attach	= 66,
		gstat_attach	= 67,
		set_db_charset	= 68,
		gsec_attach	= 69,
		address_path	= 70,
		process_id	= 71,
		no_db_triggers	= 72,
		trusted_auth	= 73,
		process_name	= 74,
		trusted_role	= 75,
		org_filename	= 76,
		utf8_filename	= 77,
		ext_call_depth	= 78,
		
		address	= 1,
		addr_protocol	= 1,
		addr_endpoint	= 2,
			
		pages	= 1,
		records	= 2,
		indices	= 4,
		transactions	= 8,
		no_update	= 16,
		repair	= 32,
		ignore	= 64,
			
		shut_cache	= 0x1,
		shut_attachment	= 0x2,
		shut_transaction	= 0x4,
		shut_force	= 0x8,
		shut_mode_mask 	= 0x70,
			
		shut_default	= 0x0,
		shut_normal	= 0x10,
		shut_multi	= 0x20,
		shut_single	= 0x30,
		shut_full	= 0x40
	} 
	
	enum isc_info_ : ubyte
	{
		db_id	= 4,
		reads	= 5,
		writes	= 6,
		fetches 	= 7,
		marks	= 8,
		
		implementation	= 11,
		isc_version	= 12,
		base_level	= 13,
		page_size	= 14,
		num_buffers	= 15,
		limbo	= 16,
		current_memory 	= 17,
		max_memory	= 18,
		window_turns	= 19,
		license	= 20,
		
		allocation	= 21,
		attachment_id	= 22,
		read_seq_count 	= 23,
		read_idx_count	= 24,
		insert_count	= 25,
		update_count	= 26,
		delete_count	= 27,
		backout_count	= 28,
		purge_count	= 29,
		expunge_count	= 30,
		sweep_interval	= 31,
		ods_version	= 32,
		ods_minor_version 	= 33,
		no_reserve	= 34,
		
		logfile	= 35,
		cur_logfile_name	= 36,
		cur_log_part_offset 	= 37,
		num_wal_buffers	= 38,
		wal_buffer_size	= 39,
		wal_ckpt_length	= 40,
		
		wal_cur_ckpt_interval	= 41,
		wal_prv_ckpt_fname	= 42,
		wal_prv_ckpt_poffset	= 43,
		wal_recv_ckpt_fname	= 44,
		wal_recv_ckpt_poffset 	= 45,
		wal_grpc_wait_usecs	= 47,
		wal_num_io	= 48,
		wal_avg_io_size	= 49,
		wal_num_commits	= 50,
		wal_avg_grpc_size	= 51,
		
		forced_writes 	= 52,
		user_names	= 53,
		page_errors	= 54,
		record_errors	= 55,
		bpage_errors	= 56,
		dpage_errors	= 57,
		ipage_errors	= 58,
		ppage_errors	= 59,
		tpage_errors	= 60,
		
		set_page_buffers	= 61,
		db_sql_dialect	= 62,
		db_read_only	= 63,
		db_size_in_pages 	= 64,
		
		frb_info_att_charset	= 101,
		db_class	= 102,
		firebird_version	= 103,
		oldest_transaction	= 104,
		oldest_active	= 105,
		oldest_snapshot	= 106,
		next_transaction	= 107,
		db_provider	= 108,
		active_transactions	= 109,
		active_tran_count	= 110,
		creation_date	= 111,
		db_file_size	= 112,
		fb_info_page_contents 	= 113,
		
		/+db_last_value+/
	} 
	
	enum isc_info_sql_ : ubyte
	{
		select	= 4,
		bind	= 5,
		num_variables	= 6,
		describe_vars	= 7,
		describe_end	= 8,
		sqlda_seq	= 9,
		message_seq	= 10,
		type	= 11,
		sub_type	= 12,
		scale	= 13,
		length	= 14,
		null_ind	= 15,
		field	= 16,
		relation	= 17,
		owner	= 18,
		alias_	= 19,
		sqlda_start	= 20,
		stmt_type	= 21,
		get_plan	= 22,
		records	= 23,
		batch_fetch	= 24,
		relation_alias	= 25
	}  
	
	enum isc_info_sql_stmt_ : ubyte
	{
		select	= 1,
		insert	= 2,
		update	= 3,
		delete	= 4,
		ddl	= 5,
		get_segment	= 6,
		put_segment	= 7,
		exec_procedure	= 8,
		start_trans	= 9,
		commit	= 10,
		rollback	= 11,
		select_for_upd	= 12,
		set_generator	= 13,
		savepoint	= 14
	} 
	
	enum DSQL_option :ushort {close = 1, drop = 2, unprepare = 4} 
	
	
	
	
	
	
	class FbFuncts
	{
		enum LOG_enabled = (常!(bool)(0)); 
		
		private: 
		
		version(/+$DIDE_REGION Core stuff+/all)
		{
			void _loadFuncts() //must be called right after it got an active opengl contect
			{
				if(!&isc_attach_database) return; //already loaded
				
				auto hFB = loadLibrary("fbclient.dll"); 
				
				void GPA(T)(ref T func, string name)
				{
					alias t = typeof(func); 
					func = cast(t)GetProcAddress(hFB, name.toStringz); 
					if(!func) raise("fb.getProcAddress fail: "~name); 
				} 
				
				//load all the function pointers in this class
				static foreach(
					fn; [FieldNameTuple!FbFuncts].filter!((a)=>(
						a.startsWith("isc_")||
						a.startsWith("fb_")
					))
				)
				mixin(iq{GPA($(fn), $(fn.quoted)); }.text); 
			} 
			
			ISC_STATUS_ARRAY global_status_vector; 
			
			extern(Windows)
			{ uint function(char* dst, uint dstLen, ISC_STATUS**) fb_interpret; } 
			
			string decodeStatus(in ref ISC_STATUS_ARRAY status_vector)
			{
				string[] res; enum maxStrLen=1024; 
				if(status_vector[].any)
				{
					static if((常!(bool)(0)))
					{
						//Note: Raw error messages
						foreach(i, status; status_vector)
						{
							if(!status) break; 
							string s = ""/+i.format!"  %2d: "+/; 
							if(i>0 && status_vector[i-1]==ISC_STATUS.arg_string)
							{ s ~= (cast(const(char)*)(status))[0..maxStrLen].toStr.safeUTF8.quoted; }
							else
							{ s ~= format!"0x%X %d %s"(status, status, (cast(ISC_STATUS)(status))); }
							res ~= s; 
						}
					}
					else
					{
						//Note: Nicer error messages formatted by fbclient.dll
						char[maxStrLen] buf; auto vector = global_status_vector.ptr; 
						while(fb_interpret(buf.ptr, buf.sizeof.to!uint, &vector))
						{
							string s = buf.toStr.safeUTF8; 
							if(true || s.map!"a<=' '".any) s = s.quoted('`'); 
							res ~= s; 
						}
					}
				}
				return ((res.empty)?(""):(i"$(res.join(", "))".text)); 
			} 
			
			string dumpValue(T)(T a)
			{
				enum maxStrLen=1024; 
				static if(
					is(typeof(a)==char*)||
					is(typeof(a)==const(char)*)||
					is(typeof(a)==immutable(char)*)
				)
				{ return a[0..maxStrLen].toStr.safeUTF8.quoted; }
				else static if(is(typeof(a)==isc_db_handle*))
				{ return "*db_handle("~ ((a)?((*a).text):("null")) ~ ")"; }
				else static if(is(typeof(a)==isc_tr_handle*))
				{ return "*tr_handle("~ ((a)?((*a).text):("null")) ~ ")"; }
				else static if(is(typeof(a)==isc_stmt_handle*))
				{ return "*stmt_handle("~ ((a)?((*a).text):("null")) ~ ")"; }
				else	{ return a.text; }
			} 
			
			ISC_STATUS CALL(alias fun, Args...)(Args args)
			{
				static if(LOG_enabled)
				{
					string pstr; 
					foreach(i, a; args)
					{
						if(i) pstr~=", "; 
						pstr ~= dumpValue(a); 
					}
					print(i"\33\13Calling:\33\16 $(fun.stringof.withoutStarting("this."))\33\7($(pstr))".text); 
				}
				ISC_STATUS status = fun(&global_status_vector, args); 
				if(status) {
					const msg = decodeStatus(global_status_vector); 
					static if(LOG_enabled) print(i"  \33\14Error:\33\7 \33\16ISC_STATUS\33\7($(msg))".text); 
					enforce(0, msg); 
				}
				return status; 
			} 
		}
		
		version(/+$DIDE_REGION DB Info+/all)
		{
			extern(Windows)
			{
				ISC_STATUS function(
					ISC_STATUS_ARRAY*, isc_db_handle*,
					short items_len, const ubyte* items,
					short buffer_len, ubyte* buffer
				) isc_database_info; ISC_STATUS function(
					ISC_STATUS_ARRAY*, isc_stmt_handle*,
					short items_len, const ubyte* items,
					short buffer_len, ubyte* buffer
				) isc_dsql_sql_info; 
			} 
			
			string get_info(THandle, TInfo)(ref THandle db_handle, in TInfo info)
			{
				static if(
					is(
						THandle==
						isc_db_handle
					)
				) {
					static assert(is(TInfo==isc_info_)); 
					enum outBufSize = 4200; 
					alias info_fun = isc_database_info; 
				}else static if(
					is(
						THandle==
						isc_stmt_handle
					)
				) {
					static assert(is(TInfo==isc_info_sql_)); 
					enum outBufSize = 1024; 
					alias info_fun = isc_dsql_sql_info; 
				}else static assert(0, "unhandled"); 
				
				try
				{
					version(/+$DIDE_REGION+/all) {
						ubyte[1] inBuf; inBuf[0] = info; 
						ubyte[outBufSize] outBuf = void; outBuf[0] = 0; 
						CALL!info_fun(
							&db_handle, 	short(1)	, inBuf.ptr,  
								short(outBufSize)	, outBuf.ptr
						); 
						enum :ubyte {
							isc_info_end	=1,
							isc_info_truncated	=2,
							isc_info_error	=3,
							isc_info_data_not_ready 	=4,
							isc_info_length	=126,
							isc_info_flag_end	=127
						}; 
						/+
							Never seen these:
							info_length: 	a special code to say “next two bytes contain a length”. 
								In practice, you treat it like a control byte that precedes a length field.
							info_flag_end: 	It marks the end of a set of flags (a flag list terminator).
						+/
						
						string res; void append(T)(T a) { res ~= ((res=="")?(""):(", ")) ~ a.text; } 
						auto buf = outBuf[]; 
						ubyte[] fetchDynBytes()
						{
							if(buf.length<2) { buf = []; return []; }
							uint len = buf[0] | buf[1]<<8; 
							if(len>buf.length+2) { buf = []; return []; }
							ubyte[] res = buf[2..$][0..len]; 
							buf = buf[2+len..$]; 
							return res; 
						} 
					}
					
					while(!buf.empty)
					{
						const 	actCode 	= buf.fetchFront,
							actInfo 	= (cast(TInfo)(actCode)),
							actName	= actInfo.text; 
						
						const isStreamMarker = actCode.inRange(1, 3)
							/+
							I threat code 4 as a property
							not as "data not ready", fuck this legacy shit!
						+/; 
						if(isStreamMarker)
						{
							switch(actCode)
							{
								case isc_info_end: 		break; 
								case 
								isc_info_truncated: 	append
								(i"Error: Truncated (larger than $(outBufSize))".text); 	break; 
								case 
								isc_info_error: 	append
								(i"Error: $(fetchDynBytes)".text); 	break; 
								case 
								isc_info_data_not_ready: 	append
								(i"Error: Data not ready".text); 	break; 
								default: 	append
								(i"Error: Unhandled code: $(actCode)".text); 	break; 
							}
							break; 
						}
						
						string caption() => ((actInfo==info)?(""):(actName~": ")); 
						
						auto raw = fetchDynBytes; 
						
						auto fetchString()
						=> raw.fetchPascalString.safeUTF8.quoted; 
						auto fetchBool()
						=> ((raw.length==1 && raw.front<=1)?(raw.front.to!bool.text):(raw.text)); 
						auto fetchInteger()
						=> ((raw.length.among(1, 2, 4))?(mixin(求sum(q{a},q{raw.enumerate},q{ulong(a.value) << (a.index*8)})).text):(raw.text)); 
						auto fetchStringArray()
						=> "["~iota(raw.fetchFront)
							.map!((i)=>(raw.fetchPascalString.safeUTF8.quoted))
						.join(", ")~"]"; 
						auto fetchHexDump()
						=> i"Block size: $(raw.length) bytes\n$(raw.hexDump)\n".text; 
						
						string data()
						{
							static if(is(TInfo==isc_info_))
							{
								with(isc_info_)
								{
									if(
										actInfo.among(
											db_id, isc_version, 
											firebird_version,
											cur_logfile_name,
											wal_prv_ckpt_fname
										)
									)
									{ return fetchStringArray; }
									if(actInfo.among(user_names))
									return fetchString; 
									if(
										actInfo.among
										(
											reads,
											writes,
											fetches,
											marks,
											page_size,
											num_buffers,
											current_memory,
											max_memory,
											allocation,
											attachment_id,
											sweep_interval,
											ods_version,
											ods_minor_version,
											logfile,
											cur_log_part_offset,
											wal_prv_ckpt_poffset,
											page_errors,
											record_errors,
											bpage_errors,
											dpage_errors,
											ipage_errors,
											ppage_errors,
											tpage_errors,
											set_page_buffers,
											db_sql_dialect,
											db_size_in_pages,
											db_class,
											oldest_transaction,
											oldest_active,
											oldest_snapshot,
											next_transaction,
											db_provider,
											active_transactions,
											active_tran_count,
											db_file_size
										)
									)
									return fetchInteger; 
									if(actInfo.among(no_reserve, forced_writes, db_read_only))
									return fetchBool; 
									if(actInfo.among(fb_info_page_contents))
									return fetchHexDump; 
								}
							}
							static if(is(TInfo==isc_info_sql_))
							{
								with(isc_info_sql_)
								{
									if(actInfo.among(stmt_type))
									{
										auto s = fetchInteger, i = s.to!int.ifThrown(-1); 
										if(i.inRange(0, 255)) s = i.to!isc_info_sql_stmt_.text; return s; 
									}
									
									if(actInfo.among(batch_fetch))
									return fetchInteger; 
								}
							}
							
							return raw.text; 
						} 
						
						append(caption ~ data); 
					}
					return res; 
				}
				catch(Exception e) { return e.simpleMsg; }
			} 
			
			public string database_info(ref isc_db_handle db, isc_info_ info)
			=> get_info(db, info);  	public string database_info(ref isc_db_handle db)
			=> [EnumMembers!isc_info_].map!((i)=>(i.text ~ "\t = " ~ database_info(db, i))).join("\n"); 
			public string sql_info(ref isc_stmt_handle stmt, isc_info_sql_ info)
			=> get_info(stmt, info);  	public string sql_info(ref isc_stmt_handle stmt)
			=> [EnumMembers!isc_info_sql_].map!((i)=>(i.text ~ "\t = " ~ sql_info(stmt, i))).join("\n"); 
			
			public isc_info_sql_stmt_ sql_info_stmt_type(ref isc_stmt_handle stmt_handle)
			{
				ubyte inBuf = isc_info_sql_.stmt_type; ubyte[8] outBuf = 0; 
				
				CALL!isc_dsql_sql_info(&stmt_handle, short(1), &inBuf, short(8), (cast(ubyte*)(outBuf.ptr))); 
				
				enforce(outBuf[0]==isc_info_sql_.stmt_type, "sql_info_stmt_type: unexpected item"); 
				enforce(outBuf[1]==4 && outBuf[2]==0, "sql_info_stmt_type: invalid length"); 
				enforce(outBuf[4]==0 && outBuf[5]==0 && outBuf[6]==0, "sql_info_stmt_type: invalid length"); 
				return (cast(isc_info_sql_stmt_)(outBuf[3])); 
			} 
			
			
		}
		
		version(/+$DIDE_REGION DB Connection+/all)
		{
			extern(Windows)
			{
				ISC_STATUS function(
					ISC_STATUS_ARRAY*,
					short db_name_length, const char* db_name,
					isc_db_handle* db_handle,
					short dpb_length, const ubyte* dpb,
					SQL_DIALECT
				) isc_create_database; 
				ISC_STATUS function(
					ISC_STATUS_ARRAY*,
					short db_name_length, const char* db_name,
					isc_db_handle* db_handle,
					short dpb_length, const ubyte* dpb
				) isc_attach_database; 
				ISC_STATUS function(ISC_STATUS_ARRAY*, isc_db_handle*) isc_detach_database; 
			} 
			
			ubyte[] buildDPB(Args...)(Args args)
			{
				ubyte[] res; 
				static foreach(a; args)
				{
					{
						alias T = typeof(a); 
						static if(is(T==isc_dpb_))	res ~= a; 
						else static if(
							T.sizeof==1 && 
							(isIntegral!T || is(T==bool))
						)	res = res ~ 1 ~ (cast(ubyte)(a)); 
						else static if(isSomeString!T)	res ~= a.text.toPascalString; 
						else static assert(0, "Unhandled type: "~T.stringof); 
					}
				}
				return res; 
			} 
			
			static string GEN_buildDPB(表 table)
			=> iq{
				() {
					with(isc_dpb_)
					return buildDPB(
						$(
							table.rows.map!"a[0..2]".join
								.filter!"a!=``".join(',')
						)
					); 
				} ()
			}.text; 
			
			public isc_db_handle create_database	(string dbPath, string user, string pass, bool create=false)
			=> attach_database(dbPath, user, pass, create: true); 
			
			public isc_db_handle attach_database	(string dbPath, string user, string pass, bool create=false)
			{
				_loadFuncts; 
				
				isc_db_handle db_handle; 
				
				const dpb = 
				mixin((
					(表([
						[q{version1},q{},q{/++/}],
						[q{user_name},q{user},q{/++/}],
						[q{password},q{pass},q{/++/}],
						[q{set_db_charset},q{"UTF8"},q{/+
							Let the FB server do the conversion automatically.
							DLang native is UTF8.
							-> std.encoding : transcode, Windows1250String
							"WIN1250" is the other option.
						+/}],
						[q{sql_dialect},q{ubyte(3)},q{/+
							Tells Firebird what SQL dialect your client uses 
							when sending statements. 
							You should pass 3 for modern Firebird (Dialect 3)
						+/}],
						[q{set_db_sql_dialect},q{ubyte(3)},q{/+
							Tells Firebird to set the database’s default dialect 
							(also 3 in modern setups). It matters when 
							creating or attaching with admin privileges; for 
							existing DBs, it’s usually already set.
						+/}],
						[q{utf8_filename},q{(常!(bool)(1))},q{/+The dbPath string is in UTF8+/}],
						[q{set_db_readonly},q{(常!(bool)(0))},q{/+
							With FB 2.5, more than 16K transactions cause 
							"Bugcheck 165 (cannot find tip page)" error if the
							db connection is readonly. So I keep this off.
						+/}],
					]))
				).調!(GEN_buildDPB))
				/+Link: https://docwiki.embarcadero.com/InterBase/2020/en/Creating_and_Populating_a_DPB+/; 
				
				void doAttach()
				{
					CALL!isc_attach_database(
						dbPath.length.to!short, dbPath.ptr, &db_handle, 
						dpb.length.to!short, dpb.ptr
					); 
					static if(LOG_enabled) print("  \33\12Attached to DB:\33\7", db_handle); 
				} 
				
				if(create)
				{
					try {
						CALL!isc_create_database(
							dbPath.length.to!short, dbPath.ptr, &db_handle, 
							dpb.length.to!short, dpb.ptr, SQL_DIALECT_3 
						); 
					}
					catch(Exception e)
					{
						((0xDD896FCAA195).檢 (global_status_vector[1])); 
						if(global_status_vector[1].among(mixin(舉!((ISC_STATUS),q{db_or_file_exists})), mixin(舉!((ISC_STATUS),q{io_error}))))
						{
							static if(LOG_enabled) print(i"  \33\16DB already exists, attaching to it...\33\7".text); 
							doAttach; 
						}
						else throw e; 
					}
				}
				else doAttach; 
				
				{
					//Enforce SQL Dialect 3
					const dialect = database_info(db_handle, isc_info_.db_sql_dialect); 
					enforce(
						dialect=="3", 
						i"Unsupported DB SQL Dialect ($(dialect)). Dialect 3 required.".text
					); 
				}
				
				/+
					Todo: Realtime database change detection. These info values can be polled: 
					/+Code: oldest_transaction, oldest_active, oldest_snapshot, next_transaction+/
				+/
				
				static if((常!(bool)(0)))
				{
					auto _間=init間; auto s = database_info(db_handle); ((0xE11C6FCAA195).檢((update間(_間)))); 
					((0xE14E6FCAA195).檢 (s)); 
				}
				
				return db_handle; 
			} 
			
			public void detach_database(ref isc_db_handle db_handle)
			{
				if(!db_handle) return; 
				ignoreExceptions({ CALL!isc_detach_database(&db_handle); }); 
				db_handle = 0/+just to make sure+/; 
			} 
		}
		
		version(/+$DIDE_REGION Transactions+/all)
		{
			extern(Windows)
			{
				ISC_STATUS function(ISC_STATUS_ARRAY*, isc_tr_handle*, short, ...) isc_start_transaction; 
				ISC_STATUS function(ISC_STATUS_ARRAY*, isc_tr_handle*) 	isc_commit_transaction, 
					isc_rollback_transaction; 
			} 
			
			ubyte[] createTPB(bool modify = false)
			{
				with(isc_tpb_)
				return [
					version3, read_committed, rec_version, wait,
					((modify)?(write /+This also implies `read`+/) :(read))
				]; 
			} 
			
			isc_tr_handle start_transaction(ref isc_db_handle db_handle, in ubyte[] tpb)
			{
				isc_tr_handle tr_handle; 
				CALL!isc_start_transaction	(
					&tr_handle, short(1)/+db count+/, &db_handle,
					tpb.length.to!short, (cast(const char*)(tpb.ptr))
				); 
				static if(LOG_enabled) print("  \33\12Transaction created:\33\7", tr_handle); 
				return tr_handle; 
			} 
			
			void commit_transaction(ref isc_tr_handle trans_handle)
			{
				if(!trans_handle) return; 
				CALL!isc_commit_transaction(&trans_handle); 
				trans_handle = 0/+just to make sure+/; 
			} 
			
			void rollback_transaction(ref isc_tr_handle trans_handle)
			{
				//Always succeeds, must be in the first scope() statement
				if(!trans_handle) return; 
				try { CALL!isc_rollback_transaction(&trans_handle); }
				catch(Exception e) { static if(LOG_enabled) print("  \33\14Rollback failed:\33\7", e.simpleMsg); }
				trans_handle = 0/+just to make sure+/; 
			} 
		}
		
		version(/+$DIDE_REGION Statements+/all)
		{
			extern(Windows) nothrow
			{
				ISC_STATUS function(
					ISC_STATUS_ARRAY*, const isc_db_handle*, 
					isc_stmt_handle*
				) isc_dsql_allocate_statement; 
				ISC_STATUS function (ISC_STATUS_ARRAY*, isc_stmt_handle*, DSQL_option) isc_dsql_free_statement; 
				
				ISC_STATUS function(
					ISC_STATUS_ARRAY*, isc_tr_handle*, isc_stmt_handle*,
					short stmt_len, const char* stmt,
					SQL_DIALECT, XSQLDA*
				) isc_dsql_prepare; 
				ISC_STATUS function(
					ISC_STATUS_ARRAY*, isc_stmt_handle*,
					SQL_DIALECT, XSQLDA*
				) isc_dsql_describe; 
				ISC_STATUS function(
					ISC_STATUS_ARRAY*, isc_stmt_handle*,
					SQL_DIALECT, XSQLDA*
				) isc_dsql_describe_bind; 
				ISC_STATUS function(
					ISC_STATUS_ARRAY*, isc_tr_handle*, isc_stmt_handle*,
					SQL_DIALECT, XSQLDA*
				) isc_dsql_execute; 
				ISC_STATUS function(
					ISC_STATUS_ARRAY*, isc_stmt_handle*,
					DA_VERSION, XSQLDA*
				) isc_dsql_fetch; 
				
			} 
			
			isc_stmt_handle dsql_allocate_statement(ref isc_db_handle db_handle)
			{
				isc_stmt_handle stmt_handle; 
				CALL!isc_dsql_allocate_statement(&db_handle, &stmt_handle); 
				static if(LOG_enabled) print("  \33\12Statement created:\33\7", stmt_handle); 
				return stmt_handle; 
			} 
			
			void dsql_drop_statement(ref isc_stmt_handle stmt_handle)
			{
				if(!stmt_handle) return; 
				try { CALL!isc_dsql_free_statement(&stmt_handle, DSQL_option.drop); }
				catch(Exception e) { static if(LOG_enabled) print("  \33\14FreeStatement failed:\33\7", e.simpleMsg); }
				stmt_handle = 0/+just to make sure+/; 
			} 
			
			void dsql_close_statement(ref isc_stmt_handle stmt_handle)
			{
				if(!stmt_handle) return; 
				try { CALL!isc_dsql_free_statement(&stmt_handle, DSQL_option.close); }
				catch(Exception e) { static if(LOG_enabled) print("  \33\14CloseStatement failed:\33\7", e.simpleMsg); }
			} 
			
			void validateXSQLDA(XSQLDA* xsqlda)
			{
				enforce(xsqlda, "XSQLDA is null"); 
				enforce(xsqlda.version_==SQLDA_VERSION1, "XSQLDA invalid version_"); 
				enforce(xsqlda.sqldaid[].equal("SQLDA   "), "XSQLDA invalid id"); 
			} 
			
			void dsql_prepare(ref isc_tr_handle tr_handle, ref isc_stmt_handle stmt_handle, string stmt, XSQLDA* xsqlda=null)
			{
				if(xsqlda) validateXSQLDA(xsqlda); 
				
				CALL!isc_dsql_prepare(
					&tr_handle, &stmt_handle, stmt.length.to!short, stmt.ptr,
					SQL_DIALECT_3, xsqlda
				); 
			} 
			
			void dsql_describe(ref isc_stmt_handle stmt_handle, XSQLDA* xsqlda)
			{
				validateXSQLDA(xsqlda); 
				CALL!isc_dsql_describe(&stmt_handle, SQL_DIALECT_3, xsqlda); 
			} 
			
			void dsql_describe_bind(ref isc_stmt_handle stmt_handle, XSQLDA* xsqlda)
			{
				validateXSQLDA(xsqlda); 
				CALL!isc_dsql_describe_bind(&stmt_handle, SQL_DIALECT_3, xsqlda); 
			} 
			
			void dsql_execute(ref isc_tr_handle tr_handle, ref isc_stmt_handle stmt_handle, XSQLDA* xsqlda)
			{
				validateXSQLDA(xsqlda); 
				CALL!isc_dsql_execute(&tr_handle, &stmt_handle, SQL_DIALECT_3, xsqlda); 
			} 
			
			bool dsql_fetch(ref isc_stmt_handle stmt_handle, XSQLDA* xsqlda)
			{
				validateXSQLDA(xsqlda); 
				ISC_STATUS status = isc_dsql_fetch(&global_status_vector, &stmt_handle, SQLDA_VERSION1, xsqlda); 
				if(status) {
					if(status==100/+no more SQL rows+/) return false; 
					raise(decodeStatus(global_status_vector)); 
				}
				return true; 
			} 
			
		}
		
		
		
		
	} 
	
	/+
		AI: /+User: Please summarize the syntax of Firebird 2.5 SQL language! Do a very dense cheat sheets prefer examples, only write desciptions when necessary!+/
		/+
			Assistant: /+H1: Firebird 2.5 SQL Cheat Sheet+/
			
			/+H2: Data Types+/
			/+
				Highlighted: SMALLINT, INTEGER, BIGINT
				FLOAT, DOUBLE PRECISION
				NUMERIC(10,2), DECIMAL(10,2)
				CHAR(10), VARCHAR(100), BLOB SUB_TYPE TEXT
				DATE, TIME, TIMESTAMP
				BOOLEAN
			+/
			
			/+H2: DDL - Table Operations+/
			/+
				Highlighted: CREATE TABLE users (
							 id INTEGER PRIMARY KEY,
							 name VARCHAR(50) NOT NULL,
							 age SMALLINT DEFAULT 0,
							 active BOOLEAN DEFAULT TRUE
				);
				
				ALTER TABLE users ADD COLUMN email VARCHAR(100);
				ALTER TABLE users DROP COLUMN age;
				DROP TABLE users;
			+/
			
			/+H2: DML - Data Manipulation+/
			/+
				Highlighted: INSERT INTO users (id, name) VALUES (1, 'John');
				INSERT INTO users VALUES (2, 'Jane', 'jane@email.com', TRUE);
				
				UPDATE users SET name = 'John Doe' WHERE id = 1;
				DELETE FROM users WHERE id = 2;
				
				SELECT * FROM users;
				SELECT name, email FROM users WHERE active = TRUE;
			+/
			
			/+H2: Constraints+/
			/+
				Highlighted: CREATE TABLE orders (
							 id INTEGER PRIMARY KEY,
							 user_id INTEGER REFERENCES users(id),
							 amount DECIMAL(10,2) CHECK (amount > 0),
							 code VARCHAR(10) UNIQUE
				);
				
				ALTER TABLE users ADD CONSTRAINT pk_users PRIMARY KEY (id);
				ALTER TABLE orders ADD CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES users(id);
			+/
			
			/+H2: Indexes+/
			/+
				Highlighted: CREATE INDEX idx_users_name ON users(name);
				CREATE DESCENDING INDEX idx_users_id_desc ON users(id);
				CREATE UNIQUE INDEX idx_users_email ON users(email);
				DROP INDEX idx_users_name;
			+/
			
			/+H2: SELECT Clauses+/
			/+
				Highlighted: SELECT DISTINCT department FROM employees;
				SELECT TOP 10 * FROM products ORDER BY price DESC;
				SELECT FIRST 10 SKIP 20 * FROM products;
				
				SELECT COUNT(*), AVG(salary), SUM(sales) FROM employees;
				SELECT department, COUNT(*) FROM employees GROUP BY department;
				SELECT department, AVG(salary) FROM employees GROUP BY department HAVING AVG(salary) > 50000;
			+/
			
			/+H2: Joins+/
			/+
				Highlighted: SELECT u.name, o.amount 
				FROM users u 
				INNER JOIN orders o ON u.id = o.user_id;
				
				SELECT u.name, o.amount 
				FROM users u 
				LEFT JOIN orders o ON u.id = o.user_id;
				
				SELECT u.name, o.amount 
				FROM users u 
				RIGHT JOIN orders o ON u.id = o.user_id;
			+/
			
			/+H2: Subqueries+/
			/+
				Highlighted: SELECT * FROM products WHERE price > (SELECT AVG(price) FROM products);
				SELECT name FROM users WHERE id IN (SELECT user_id FROM orders);
				SELECT name, (SELECT COUNT(*) FROM orders WHERE user_id = users.id) AS order_count FROM users;
			+/
			
			/+H2: Views+/
			/+
				Highlighted: CREATE VIEW active_users AS 
				SELECT id, name, email FROM users WHERE active = TRUE;
				
				CREATE OR ALTER VIEW user_orders AS
				SELECT u.name, COUNT(o.id) AS order_count
				FROM users u LEFT JOIN orders o ON u.id = o.user_id
				GROUP BY u.id, u.name;
				
				DROP VIEW active_users;
			+/
			
			/+H2: Stored Procedures+/
			/+
				Highlighted: CREATE PROCEDURE get_user_orders(user_id INTEGER)
				RETURNS (order_id INTEGER, amount DECIMAL(10,2))
				AS
				BEGIN
							 FOR SELECT id, amount FROM orders 
							 WHERE user_id = :user_id
							 INTO :order_id, :amount
							 DO SUSPEND;
				END;
				
				EXECUTE PROCEDURE get_user_orders(123);
			+/
			
			/+H2: Functions+/
			/+
				Highlighted: CREATE FUNCTION calculate_tax(amount DECIMAL(10,2))
				RETURNS DECIMAL(10,2)
				AS
				BEGIN
				    RETURN amount * 0.20;
				END;
				
				SELECT calculate_tax(100.00) FROM rdb$database;
			+/
			
			/+H2: Transactions+/
			/+
				Highlighted: SET TRANSACTION READ WRITE ISOLATION LEVEL SNAPSHOT;
				INSERT INTO orders VALUES (1, 100.00);
				COMMIT;
				
				SET TRANSACTION;
				UPDATE users SET balance = balance - 100 WHERE id = 1;
				UPDATE users SET balance = balance + 100 WHERE id = 2;
				ROLLBACK;
			+/
			
			/+H2: Common Functions+/
			/+
				Highlighted: -- String
				UPPER('text'), LOWER('TEXT'), TRIM('  text  ')
				SUBSTRING('Hello' FROM 2 FOR 3) -- 'ell'
				CHAR_LENGTH('text')
				
				-- Date/Time
				CURRENT_DATE, CURRENT_TIME, CURRENT_TIMESTAMP
				EXTRACT(YEAR FROM timestamp), EXTRACT(MONTH FROM timestamp)
				DATEADD(DAY, 7, CURRENT_DATE)
				
				-- Math
				ABS(-5), CEIL(4.3), FLOOR(4.7), ROUND(4.567, 2)
				MOD(10, 3) -- 1
				
				-- Conditional
				COALESCE(NULL, NULL, 'default') -- 'default'
				NULLIF(column, 0) -- NULL if column = 0
				CASE WHEN active THEN 'Yes' ELSE 'No' END
			+/
			
			/+H2: System Tables+/
			/+
				Highlighted: SELECT * FROM rdb$relations; -- All tables/views
				SELECT * FROM rdb$fields; -- Columns
				SELECT * FROM rdb$indices; -- Indexes
				SELECT * FROM rdb$procedures; -- Stored procedures
			+/
			
			/+H2: Privileges+/
			/+
				Highlighted: GRANT SELECT, INSERT ON users TO user1;
				GRANT ALL ON users TO PUBLIC;
				REVOKE DELETE ON users FROM user1;
			+/
			
			/+H2: PSQL (Procedural SQL) Constructs+/
			/+
				Highlighted: -- Variables
				DECLARE VARIABLE var_name INTEGER;
				var_name = 10;
				
				-- Control flow
				IF (condition) THEN
				    statement;
				ELSE IF (condition) THEN
				    statement;
				ELSE
				    statement;
				
				WHILE (condition) DO
				BEGIN
				    statement;
				END
				
				FOR SELECT column INTO :var FROM table DO
				BEGIN
				    statement;
				END
				
				-- Exceptions
				WHEN ANY DO
				BEGIN
				    -- error handling
				END
			+/
			
			/+H2: Generator (Sequences)+/
			/+
				Highlighted: CREATE GENERATOR gen_users_id;
				SET GENERATOR gen_users_id TO 1000;
				SELECT GEN_ID(gen_users_id, 1) FROM rdb$database; -- Next value
				DROP GENERATOR gen_users_id;
			+/
			
			/+H2: BLOB Operations+/
			/+
				Highlighted: CREATE TABLE documents (
							 id INTEGER PRIMARY KEY,
							 content BLOB SUB_TYPE TEXT
				);
				
				INSERT INTO documents VALUES (1, 'Text content');
				SELECT SUBSTRING(content FROM 1 FOR 100) FROM documents;
			+/
		+/
		/+User: Add string quotes and comments and other low level syntax elements!+/
		/+
			Assistant: 			
			/+H1: Firebird 2.5 SQL Low-Level Syntax+/
			
			/+H2: 	String Literals & Quotes+/
				/+
				Highlighted: 'Single quoted string'
				'It''s escaped with two quotes'
				'Multi-line
				string literal'
				_win1250 'Text in specific charset'
				N'National character string'
				Q'{Braced string with 'quotes'}'
				Q'!Delimited string with 'quotes'!'
			+/
			
				/+H2: Comments+/
				/+
				Highlighted: -- Single line comment
				/*Multi-line
				comment */
				SELECT FROM users -- Inline comment
				WHERE active = TRUE; /* Filter active users */
			+/
				
				/+H2: Identifiers & Naming+/
				/+
				Highlighted: Regular: users, order_details, column_name
				Quoted: "Users", "Order Details", "Column-Name"
				"123table" -- Numbers allowed when quoted
				"select" -- Reserved word as identifier
				CREATE TABLE "My Table" ("Column 1" INTEGER);
			+/
				
				/+H2: Numeric Literals+/
				/+
				Highlighted: 123 -- Integer
				3.14 -- Decimal
				-45.67 -- Negative
				1.23E-4 -- Scientific notation
				0xFF -- Hexadecimal integer
			+/
				
				/+H2: Boolean Literals+/
				/+
				Highlighted: TRUE
				FALSE
				UNKNOWN -- Three-valued logic
				SELECT FROM users WHERE active IS TRUE;
				SELECT FROM users WHERE active IS NOT FALSE;
			+/
				
				/+H2: NULL & Special Values+/
				/+
				Highlighted: NULL
				CURRENT_DATE
				CURRENT_TIME
				CURRENT_TIMESTAMP
				'NOW' -- Timestamp literal
				'TODAY' -- Date literal
				'YESTERDAY' -- Date literal
				SELECT FROM users WHERE email IS NULL;
				SELECT FROM logs WHERE created > 'YESTERDAY';
			+/
				
				/+H2: Operators+/
				/+
				Highlighted: -- Arithmetic
				+ - * /
				
				-- Comparison
				= <> != < > <= >=
				IS NULL, IS NOT NULL
				BETWEEN 1 AND 10
				IN (1, 2, 3)
				LIKE 'A%'
				CONTAINING 'text'
				STARTING WITH 'A'
				
				-- Logical
				AND OR NOT
				
				-- String concatenation
				'Hello' || ' ' || 'World'
				'Prefix' || column_name
			+/
				
				/+H2: Escape Sequences in Strings+/
				/+
				Highlighted: 'Line 1' || ASCII_CHAR(13) || ASCII_CHAR(10) || 'Line 2'
				'Tab' || ASCII_CHAR(9) || 'separated'
				'Unicode: ' || _unicode x'0041' -- 'A'
			+/
				
				/+H2: Date/Time Literals+/
				/+
				Highlighted: DATE '2023-12-25'
				TIME '14:30:00'
				TIMESTAMP '2023-12-25 14:30:00'
				SELECT FROM events WHERE event_date = DATE '2023-12-25';
			+/
				
				/+H2: BLOB Literals+/
				/+
				Highlighted: x'4D5A' -- Binary hex literal
				BLOB 'Text blob content'
				SELECT x'010203' FROM rdb$database;
			+/
				
				/+H2: Parameter Markers+/
				/+
				Highlighted: ? -- Positional parameter
				:param_name -- Named parameter
				SELECT  FROM users WHERE id = ?;
				UPDATE users SET name = :new_name WHERE id = :user_id;
			+/
				
				/+H2: Statement Terminators+/
				/+
				Highlighted: ; -- Standard terminator
				SET TERM ^ ; -- Change terminator
				CREATE PROCEDURE test
				AS
				BEGIN
				    -- procedure body
				END^
				SET TERM ; ^ -- Restore terminator
			+/
				
				/+H2: PSQL Specific Syntax+/
				/+
				Highlighted: -- Variable declaration
				DECLARE VARIABLE var INTEGER;
				DECLARE VARIABLE str VARCHAR(100);
				
				-- Assignment
				var = 10;
				str = 'Hello';
				SELECT name INTO :var FROM users WHERE id = 1;
				
				-- Compound statements
				BEGIN
					statement1;
					statement2;
				END
				
				-- Exception blocks
				WHEN ANY DO
				BEGIN
					-- Error handling
					EXIT;
				END
			+/
				
				/+H2: Special PSQL Constructs+/
				/+
				Highlighted: POST_EVENT 'EventName'; -- Event signaling
				EXECUTE STATEMENT 'SELECT FROM users'; -- Dynamic SQL
				FOR EXECUTE STATEMENT query INTO :var DO
				BEGIN
					-- Process results
				END
			+/
				
				/+H2: Casting & Conversion+/
				/+
				Highlighted: CAST(123 AS VARCHAR(10))
				CAST('2023-12-25' AS DATE)
				CAST(column_name AS INTEGER)
				SELECT CAST(CURRENT_TIMESTAMP AS DATE) FROM rdb$database;
			+/
				
				/+H2: Collation & Character Sets+/
				/+
				Highlighted: 'text' COLLATE UNICODE_CI
				'text' COLLATE WIN1250_CI_AI
				CREATE TABLE users (
				    name VARCHAR(100) CHARACTER SET UTF8 COLLATE UNICODE_CI
				);
			+/
		+/
	+/
}
version(/+$DIDE_REGION+/all) {
	class FbFields
	{
		enum align_enabled = (常!(bool)(0))/+Todo: Benchmark the effect of this!+/; 
		
		ubyte[] infoBuf, dataBuf; 
		
		@property XSQLDA* xsqlda() => (cast(XSQLDA*)(infoBuf.ptr)); 
		@property XSQLVAR[] vars() => xsqlda.sqlvar.ptr[0 .. xsqlda.sqld]; 
		private XSQLVAR*[string] pvarByName; 
		
		ref opIndex(size_t i)
		=> vars[i]; size_t length()
		=> vars.length; 
		
		XSQLVAR* opIndex(string s)
		=> pvarByName.get(s, null); XSQLVAR* opDispatch(string name)()
		=> this[name]; 
		
		
		string sqlText /+prepared sql thext after input+/; 
		size_t inputSignature; 
		
		/+
			Use cases:
			 1. Create data buffer layout for statement output
				/+Code: f = new FbFields(NumFields); ...; f.reallocInfoIfNeeded; f.prepareOutput;+/
			 2. Create input layout for statement parameters and fill it with data
				/+Code: f = new FbFields; f.prepareInput((i"SELECT $(1+1)")); /+use /+Code: f.sqlText+/+/+/
			And then give /+Code: f.xsqlda+/ to isc_dsql_ functions!
		+/
		
		this()
		{} 	 this(uint n)
		{ allocInfo(n); } 
		
		void allocInfo(uint n)
		{
			infoBuf.length = XSQLDA_LENGTH(n.to!int); 
			with(xsqlda)
			{
				version_ = SQLDA_VERSION1; 
				sqldaid[] = "SQLDA   "; 
				sqln = n.to!short; 
				sqld = 0; 
			}
		}  bool reallocInfoIfNeeded()
		{
			if(!xsqlda) return false; 
			if(xsqlda.sqld<=xsqlda.sqln) return false; 
			auto need = xsqlda.sqld; 
			allocInfo(need.to!uint); 
			return true; 
		} 
		
		void prepareOutput()
		{ prepareDataBuf; 	/+allocate and layout data buffer+/} 
		
		void reset()
		{
			allocInfo(0); dataBuf = []; 
			sqlText = ""; inputSignature = 0; 
		} 
		
		static size_t calcInputSignature(Args...)(string[] literals)
		{
			size_t h = "XSQLDA_INPUT_SIGNATURE".hashOf; 
			static foreach(T; Args) {
				{
					static if(!is(Unqual!T==InterpolatedExpression!e, string e))
					h = h.mix64(T.stringof.hashOf); 
				}
			}
			foreach(lit; literals) h = h.mix64(lit.hashOf); 
			return h; 
		} 
		static assert(
				calcInputSignature!(InterpolatedExpression!"ignored1")(["x"])
			==	calcInputSignature!(InterpolatedExpression!"ignored2")(["x"])
		); 
		
		private void fieldsToXsqlda(bool[] nullables, SQL_TYPE[] types, ushort[] lens)
		{
			allocInfo(types.length.to!uint); 
			with(xsqlda) sqld = sqln; 
			
			foreach(i, ref var; vars)
			with(vars[i]) {
				sqltype 	= (cast(short)(types[i] + (nullables[i] ? 1 : 0))),
				sqllen 	= lens[i]; 
			}
		} 
		
		private void prepareDataBuf()
		{
			uint[] nullOffsets, dataOffsets; uint totalSize = 0; 
			
			static short requiredSize(in SQL_TYPE type, short len)
			{
				with(SQL_TYPE)
				final switch(type)
				{
					case VARYING: 	return (2 + len)
					.to!short; 
					case TEXT: 	return len; 
					case SHORT: 	return 2; 
					case LONG: 	return 4; 
					case INT64: 	return 8; 
					case FLOAT: 	return 4; 
					case DOUBLE: 	return 8; 
					case D_FLOAT: 	return 8; 
					case DATE: 	return 4; 
					case TIME: 	return 4; 
					case TIMESTAMP: 	return 8; 
					case QUAD: 	return 8; 
					case BLOB: 	return 8; 
					case ARRAY: 	return 8; 
						
					case NULL: 	return 2; 
				}
			} 
			
			static auto layoutField(in bool isNullable, in SQL_TYPE type, in ushort len, ref uint actOfs)
			{
				enforce(len.inRange(1, 0x7fff), "`len` out of range"); 
				
				void alignOfs(uint n)
				{ if(align_enabled) actOfs = actOfs.alignUp(n); } 
				void alignOfs16_back2()
				{ if(align_enabled) while(actOfs % 16 != 16-2) actOfs++; } 
				
				version(/+$DIDE_REGION Null indicator (optional)+/all)
				{
					if(isNullable) actOfs = actOfs.alignUp(2); 
					uint nullOfs = actOfs; 
					if(isNullable) actOfs += 2; 
				}
				
				version(/+$DIDE_REGION Actual data+/all)
				{
					/+The 1st char of strings must be 16byte aligned. Other data is aligned to its size.+/
					with(SQL_TYPE)
					final switch(type)
					{
						case VARYING: 	alignOfs16_back2; 	break; 
						case TEXT: 	alignOfs(16); 	break; 
						case SHORT, NULL: 	alignOfs(2); 	break; 
						case 	DATE, TIME, LONG, 	FLOAT: 	alignOfs(4); 	break; 
						case 	INT64, DOUBLE, D_FLOAT, 
							TIMESTAMP, QUAD, BLOB, ARRAY: 	alignOfs(8); 	break; 
					}
					uint dataOfs = actOfs; 
					actOfs += requiredSize(type, len); 
				}
				struct Res { uint nullOfs, dataOfs; } 
				return Res(nullOfs, dataOfs); 
			} 
			
			{
				uint actOfs = 0; 
				foreach(ref var; vars)
				{
					const layout = layoutField(var.isNullable, var.type, var.sqllen.to!ushort, actOfs); 
					nullOffsets ~= layout.nullOfs; 
					dataOffsets ~= layout.dataOfs; 
				}
				totalSize = actOfs.alignUp(align_enabled ? 16 : 1); 
			}
			
			{
				dataBuf = new ubyte[totalSize]; 
				uint actOfs = 0; 
				foreach(i, ref var; vars)
				{
					var.sqldata = dataBuf.ptr + dataOffsets[i],
					var.sqlind = ((var.isNullable)?((cast(short*)(dataBuf.ptr + nullOffsets[i]))):(null)); 
				}
			}
			
			{
				pvarByName.clear; 
				foreach(ref v; vars) pvarByName[v.aliasName] = &v; 
				pvarByName.rehash; 
			}
		} 
		
		void prepareInput(Args...)(string[] literals)
		{
			reset; 
			void appendSql(string s) { sqlText ~= s; } 
			
			version(/+$DIDE_REGION Internal state for functions+/all)
			{ bool[] nullables; SQL_TYPE[] types; ushort[] lens; auto literalIdx=0; }
			
			void appendField(bool isNullable, SQL_TYPE type, size_t len)
			{
				nullables ~= isNullable; 
				types ~= type; 
				lens ~= len.to!ushort; 
			} 
			
			void processParam(T_)()
			{
				static if(is(Unqual!T_==Nullable!NT, NT))
				{
					enum isNullable = true; 
					alias T = Unqual!NT; 
				}else {
					enum isNullable = false; 
					alias T = Unqual!T_; 
				}
				
				void append(string s, SQL_TYPE type, size_t len)
				{ appendSql(s); appendField(isNullable, type, len); } 
				
				enum DefaultVarcharLength = 80; 
				void prepareVarchar(size_t N)
				{
					enforce(mixin(界3(q{1},q{N},q{0x7FFF})), i"Invalid Varchar length. $(N)".text); 
					append(i"CAST(? AS VARCHAR($(N)))".text, SQL_TYPE.VARYING, N); 
				} 
				
				static if(isIntegral!T || is(T==bool))
				{
					static if(
						is(T==ubyte) || 
						is(T==byte) || 
						is(T==short) || 
						is(T==bool)
					)	{ append("CAST(? AS SMALLINT)", SQL_TYPE.SHORT, 2); }
					else static if(
						is(T==ushort) || 
						is(T==int)
					)	{ append("CAST(? AS INT)", SQL_TYPE.LONG, 4); }
					else static if(
						is(T==uint) || 
						is(T==long)
					)	{ append("CAST(? AS BIGINT)", SQL_TYPE.INT64, 8); }
					else static if(is(T==ulong))
					static assert(0, "ULONG is not safely representable as a Firebird integer."); 
					else static assert(0, "Unhandled integral IES type: " ~ T.stringof); 
				}
				else static if(isFloatingPoint!T)
				{
					static if(is(T==float))	{ append("CAST(? AS FLOAT)", SQL_TYPE.FLOAT, 4); }
					else static if(is(T==double))	{ append("CAST(? AS DOUBLE PRECISION)", SQL_TYPE.DOUBLE, 8); }
					else static assert(0, "Unhandled floating IES type: " ~ T.stringof); 
				}
				else static if(is(T==Varchar!N, uint N))	{ prepareVarchar(N); }
				else static if(is(T==string))	{ prepareVarchar(DefaultVarcharLength); }
				else static if(is(T==Date))	{ append("CAST(? AS DATE)", SQL_TYPE.DATE, 4); }
				else static if(is(T==Time))	{ append("CAST(? AS TIME)", SQL_TYPE.TIME, 4); }
				else static if(is(T==DateTime))	{ append("CAST(? AS TIMESTAMP)", SQL_TYPE.TIMESTAMP, 8); }
				else static assert(0, "Unhandled IES type: " ~ T.stringof); 
			} 
			
			version(/+$DIDE_REGION Prepare field metadata+/all)
			{
				{
					uint actIdx=0; 
					static foreach(A; Args)
					{
						{
							alias T = Unqual!(A); 
							static if(is(T==InterpolationHeader))	{}
							else static if(is(T==InterpolationFooter))	{}
							else static if(
								is(
									T==InterpolatedLiteral!str,
									string str
								)
							)	{ appendSql(str); }
							else static if(
								is(
									T==InterpolatedExpression!expr,
									string expr
								)
							)	{ actIdx++; }
							else static if(isLiteral!T)	{ appendSql(literals[literalIdx++]); }
							else	{ processParam!T; }
						}
					}
				}
			}
			
			sqlText = sqlText.convertTokenStringToSQL; 
			
			fieldsToXsqlda(nullables, types, lens); 
			prepareDataBuf; 
			
			inputSignature = calcInputSignature!(Args)(literals); 
		} 
			
		void fillInput(Args...)(Args args)
		{
			version(/+$DIDE_REGION Internal state for functions+/all)
			{ uint paramIdx=0; }
			
			
			
			
			
			
			
			
			
			
			void placeParam(T_)(T_ arg)
			{
				static if(is(Unqual!T_==Nullable!NT, NT))
				{
					enum isNullable = true; 
					auto isNull() => arg.isNull; 
					auto get() => arg.get; 
					alias T = Unqual!NT; 
				}else {
					enum isNullable = false; 
					enum isNull = false; 
					auto get() => arg; 
					alias T = Unqual!T_; 
				}
				
				ref var = vars[paramIdx]; 
				static if(isNullable) *var.sqlind = ((isNull)?(-1):(0)); 
				
				if(!isNullable || !isNull)
				{
					void placeVarchar(string str)
					{
						enforce(
							str.length<=var.sqllen,
							i"String too long for VARCHAR: $(str.length) > $(var.sqllen)".text
						); 
						*(cast(short*)(var.sqldata)) = (cast(short)(str.length)); 
						(cast(char*)(var.sqldata))[2..2+str.length] = str; 
					} 
					
					static if(isIntegral!T || is(T==bool))
					{
						static if(
							is(T==ubyte) || 
							is(T==byte) || 
							is(T==short) || 
							is(T==bool)
						)	{ *(cast(short*)(var.sqldata)) = get.to!short; }
						else static if(
							is(T==ushort) || 
							is(T==int)
						)	{ *(cast(int*)(var.sqldata)) = get.to!int; }
						else static if(
							is(T==uint) || 
							is(T==long)
						)	{ *(cast(long*)(var.sqldata)) = get.to!long; }
						else static if(is(T==ulong))
						static assert(0, "ULONG is not safely representable as a Firebird integer."); 
						else static assert(0, "Unhandled integral IES type: " ~ T.stringof); 
					}
					else static if(isFloatingPoint!T)
					{
						static if(is(T==float))	{ *(cast(float*)(var.sqldata)) = 	get.to!float; }
						else static if(is(T==double))	{ *(cast(double*)(var.sqldata)) = 	get.to!double; }
						else static assert(0, "Unhandled floating IES type: " ~ T.stringof); 
					}
					else static if(is(T==Varchar!N, uint N)) { placeVarchar(get.value); }
					else static if(is(T==string))	{ placeVarchar(get); }
					else static if(is(T==Date))	{ *(cast(ISC_DATE*)(var.sqldata)) = get.toIscDate; }
					else static if(is(T==Time))	{ *(cast(ISC_TIME*)(var.sqldata)) = get.toIscTime; }
					else static if(is(T==DateTime))	{
						*(cast(ISC_TIMESTAMP*)(var.sqldata)) = 
							get.localFileTime.toIscTimestamp; 
					}
					else static assert(0, "Unhandled IES type: " ~ T.stringof); 
				}
			} 
			
			version(/+$DIDE_REGION Append actual data+/all)
			{
				{
					uint actIdx=0; 
					static foreach(i, arg; args)
					{
						{
							alias T = Unqual!(typeof(arg)); 
							static if(is(T==InterpolationHeader))	{}
							else static if(is(T==InterpolationFooter))	{}
							else static if(
								is(
									T==InterpolatedLiteral!str,
									string str
								)
							)	{}
							else static if(
								is(
									T==InterpolatedExpression!expr, 
									string expr
								)
							)	{ paramIdx = actIdx++; }
							else static if(isLiteral!T)	{}
							else	{ placeParam(arg); }
						}
					}
				}
			}
		} 
	} 
	
	class FbDatabase
	{
		/+NOT THREADSAFE!+/
		
		isc_db_handle db_handle; 
		this(isc_db_handle db_handle)
		{ this.db_handle = db_handle.enforce("NULL db_handle."); } 
		
		this(string dbPath, string user, string pass, bool create=false)
		{ this(fb.attach_database(dbPath, user, pass, create: create)); } 
		
		~this()
		{
			if(activeTransactionCount)
			ERR(i"There were active transactions: amount: $(activeTransactionCount) db_handle:$(db_handle)"); 
			//ignore cached statements: those will be freed by the server.
			fb.detach_database(db_handle); 
		} 
		
		version(/+$DIDE_REGION StatementCache+/all)
		{
			struct Statement {
				isc_stmt_handle stmt_handle; 
				FbFields inputFields, outputFields; 
			} 
			Statement[ulong] statementCache; 
			
			void clearStatementCache()
			{
				foreach(ref s; statementCache.byValue) fb.dsql_drop_statement(s.stmt_handle); 
				statementCache.clear; 
			} 
			
			private auto accessStatement(Args...)(ref isc_tr_handle trans_handle, string[] literals)
			{
				const inputSignature = FbFields.calcInputSignature!Args(literals); 
				
				Statement statement = statementCache.get(inputSignature); 
				if(!statement.stmt_handle)
				{
					with(fb)
					{
						isc_stmt_handle stmt_handle; 
						stmt_handle = dsql_allocate_statement(db_handle); 
						scope(failure) dsql_drop_statement(stmt_handle); 
						
						auto inputFields = new FbFields; 
						inputFields.prepareInput!Args(literals); 
						const sqlText = inputFields.sqlText; 
						dsql_prepare(trans_handle, stmt_handle, sqlText); 
						dsql_describe_bind(stmt_handle, inputFields.xsqlda); 
						
						FbFields outputFields = null /+not for all statements+/; 
						if(
							sql_info_stmt_type(stmt_handle).among
								(mixin(舉!((isc_info_sql_stmt_),q{select})), mixin(舉!((isc_info_sql_stmt_),q{exec_procedure})))
						)
						{
							outputFields = new FbFields(1); 
							dsql_describe(stmt_handle, outputFields.xsqlda); 
							if(outputFields.reallocInfoIfNeeded)
							dsql_describe(stmt_handle, outputFields.xsqlda); 
							outputFields.prepareOutput; 
						}
						
						//print("SQL INFO:\n"~sql_info(stmt_handle).split("\n").map!`"  "~a`.join('\n')); 
						
						statement = Statement(stmt_handle, inputFields, outputFields); 
						statementCache[inputSignature] = statement; 
					}
				}
				return statement; 
			} 
		}
		
		protected {
			size_t activeTransactionCount;  void _notifyTransactionCreated(Transaction tr)
			{ activeTransactionCount++; }  void _notifyTransactionDestroyed(Transaction tr)
			{ activeTransactionCount--; } 
		} 
		
		class Transaction
		{
			isc_tr_handle trans_handle; 
			uint errorCount=0; 
			
			bool active()const => !!trans_handle; 
			
			this(bool modify = false)
			{
				trans_handle = fb.start_transaction	(db_handle, fb.createTPB(modify: modify)); 
				_notifyTransactionCreated(this); 
			} 
			
			~this()
			{ if(active) { rollback; WARN("Dangling active transaction."); }} 
			
			void enforceActive()
			{ enforce(active, "Transaction must be active."); } 
			
			void commit()
			{
				if(active) {
					fb.commit_transaction(trans_handle); assert(!active); 
					_notifyTransactionDestroyed(this); 
				}
			} 
			
			void rollback()
			{
				if(active) {
					fb.rollback_transaction(trans_handle); assert(!active); 
					_notifyTransactionDestroyed(this); 
				}
			} 
			
			static struct ResultSet
			{
				private {
					FbFields fields_; 
					isc_stmt_handle handle_; 
					Transaction ownedTransaction; 
				} 
				
				@property fields() => fields_; 
				@property empty() => !handle_; 
				//This is NOT an InputRange, it has opApply() with empty().
				
				@disable this(this); 
				this(FbFields fields, isc_stmt_handle handle)
				{
					fields_ = fields, handle_ = handle; 
					if(fields is null)
					{ close; /+it has no result set.+/}
					else
					{
						//fetch the very first row
						scope(failure) close; 
						if(!fb.dsql_fetch(handle_, fields.xsqlda)) close; 
					}
				} 
				
				~this() { close; } 
				
				void close()
				{
					if(handle_) {
						scope(exit) { handle_ = 0; }
						fb.dsql_close_statement(handle_); 
					}
					freeTransaction(ownedTransaction); 
				} 
				
				int opApply(scope int delegate(FbFields) dg)
				{
					scope(exit) close(); 
					while(handle_)
					{
						const res = dg(fields_); 
						if(res) return res; 
						if(!fb.dsql_fetch(handle_, fields.xsqlda)) break; 
					}
					return 0; 
				} 
			} 
			
			scope ResultSet execute(Args...)(Args args)
			{
				enforceActive; 
				scope(failure) errorCount++; 
				
				version(/+$DIDE_REGION Collect literal SQL strings+/all)
				{
					enum numLiterals = Filter!(isLiteral, Args).length; 
					string[numLiterals] literals; 
					static if(numLiterals)
					{
						{
							auto literalIdx = 0; 
							static foreach(a; args)
							static if(isLiteral!(typeof(a)))
							literals[literalIdx++] = a.value; 
						}
					}
				}
				
				auto statement = accessStatement!(Args)(trans_handle, literals[]); 
				statement.inputFields.fillInput(args); 
				fb.dsql_execute(
					trans_handle, statement.stmt_handle, 
					statement.inputFields.xsqlda
				); 
				return ResultSet(statement.outputFields, statement.stmt_handle); 
			} 
			
			scope ResultSet 查(Args...)(LOCATION_t loc, Args args)
			{
				/+
					Example input:
					/+
						Code: c:\codex\d\firebird\firebird.d(3276,1),
						(
							InterpolationHeader, 
								InterpolatedLiteral!"options", 
							InterpolationFooter, 
							InterpolationHeader, 
								InterpolatedLittoStringeral!"SELECT ", 
								InterpolatedExpression!"1", int, 
								InterpolatedLiteral!"+", 
								InterpolatedExpression!"2", int, 
								InterpolatedLiteral!" FROM RDB$DATABASE", 
							InterpolationFooter
						)
					+/
				+/
				
				enum endIdx = staticIndexOf!(InterpolationFooter, Args); 
				static assert(endIdx>=1); 
				alias optionArgs 	= args[1..endIdx /+no header/footer+/], 
				queryArgs 	= args[endIdx+1..$]; 
				
				static if(optionArgs.length<=1)
				{
					static if(optionArgs.length)
					{
						static if(
							is(
								typeof(optionArgs[0])==
								InterpolatedLiteral!str, string str
							)
						)
						enum queryOptions = str; 
					}
					else	enum queryOptions = ""; 
				}
				static assert(
					__traits(compiles, queryOptions), 
					"Invalid options format. Only static options are valid."
				); 
				
				//print(loc); print(queryOptions.stringof); 
				try
				{ return execute(queryArgs); }
				catch(Exception e)
				{
					auto 	cl = CodeLocation(loc.text),
						file = cl.file.fullName, line = cl.lineIdx,
						msg = e.simpleMsg; 
					if(msg.isWild("`Dynamic SQL Error`, `SQL error code = ?*`, `?* - line ?*, column ?*`*"))
					{
						msg = i"Dynamic SQL Error($(wild[0])): $(wild[1])$(wild[4])".text; 
						line += wild.ints(2)-1; 
					}
					else if(msg.isWild("`Dynamic SQL Error`, `SQL error code = ?*`, ?*, `At line ?*, column ?*`"))
					{
						msg = i"Dynamic SQL Error($(wild[0])): $(wild[1])".text; 
						line += wild.ints(2)-1; 
					}
					else if(msg.isWild("`Dynamic SQL Error`, `SQL error code = ?*`, ?*"))
					{ msg = i"Dynamic SQL Error($(wild[0])): $(wild[1])".text; }
					enforce(0, msg, file, line); assert(0); 
				}
			} 
		} 
		
		Transaction startTransaction(bool modify = false)
		{ return new Transaction(modify: modify); } 
		
		private static void freeTransaction(ref Transaction tr)
		{
			if(tr) {
				scope(exit) tr.free; 
				if(tr.active)	{ ((tr.errorCount>0)?(tr.rollback) :(tr.commit)); }
			}
		} 
		
		static struct ScopedTransaction
		{
			private Transaction transaction_; 
			@property Transaction transaction() => transaction_; 
			
			alias this = transaction; 
			
			@disable this(this); 
			this(Transaction transaction)
			{ transaction_ = transaction; } 
			
			~this()
			{ freeTransaction(transaction_); } 
		} 
		
		scope transaction(bool modify = false)
		=> ScopedTransaction(startTransaction(modify: modify)); 
		
		scope FbResultSet 查(Args...)(LOCATION_t loc, Args args)
		{
			auto tr = startTransaction, res = tr.查!Args(loc, args); 
			res.ownedTransaction = tr; return res; 
		} 
		
		/+
			RDB$RELATIONS columns (2.5):
			
			 - RDB$RELATION_NAME (CHAR(31)) 	table/view name
			 - RDB$RELATION_ID (SMALLINT) 	internal id
			 - RDB$RELATION_TYPE (SMALLINT) 	relation type (table, view, GTT, etc.)
			 - RDB$VIEW_BLR (BLOB BLR) 	view BLR; NULL for tables
			 - RDB$VIEW_SOURCE (BLOB TEXT) 	view SQL source; NULL for tables
			 - RDB$DESCRIPTION (BLOB TEXT) 	comment/description
			 - RDB$SYSTEM_FLAG (SMALLINT) 	system vs user (0 = user)
			 - RDB$DBKEY_LENGTH (SMALLINT) 	size of dbkey
			 - RDB$FORMAT (SMALLINT) 	internal, points into RDB$FORMATS
			 - RDB$FIELD_ID (SMALLINT) 	next field id for new columns
			 - RDB$SECURITY_CLASS (CHAR(31)) 	security class
			 - RDB$EXTERNAL_FILE (VARCHAR(255)) 	external file path (if external table)
			 - RDB$RUNTIME (BLOB) 	internal metadata
			 - RDB$EXTERNAL_DESCRIPTION (BLOB) 	comments for external file
			 - RDB$OWNER_NAME (CHAR(31)) 	creator user
			 - RDB$DEFAULT_CLASS (CHAR(31)) 	default security class for new cols
			 - RDB$FLAGS (SMALLINT) 	internal flags
			
			Source: Firebird language reference, system tables appendix.
			/+
				Link: https://www.firebirdsql.org/file/documentation/chunk/en/refdocs/fblangref30/
				fblangref-appx04-relations.html?utm_source=openai)
			+/
		+/
		
		auto allTablesAndViews(string mask="*", bool tables=true, bool views=true)
		{
			with(transaction)
			return (查((位!()),iq{},iq{
				SELECT rdb$relation_name FROM rdb$relations
				WHERE rdb$system_flag=0
				AND(
						$(tables)	=1 AND rdb$view_blr IS NULL
					OR	$(views)	=1 AND rdb$view_blr IS NOT NULL
				)
			}))
			.toArray!string.filter!((a)=>(a.isWild(mask))).array; 
		} 
		auto allTables(string mask="*")
		=> allTablesAndViews(mask, views: false); auto allViews(string mask="*")
		=> allTablesAndViews(mask, false); 
		
		scope FbResultSet fetchTable(string tableName)
		{
			auto tr = new Transaction; scope(failure) tr.free; 
			FbResultSet res; 
			with(tr) res = (查((位!()),iq{},iq{SELECT * FROM $(Literal(tableName))})); 
			res.ownedTransaction = tr; /+
				The Resultset owns this transaction.
				It will close it when it's done.
			+/
			return res; 
		} 
		
		string fetchHeaders(string mask="*")
		=> mixin(求map(q{name},q{allTablesAndViews(mask)},q{fetchTable(name).formatTable (TableStyle.struct_hdr)})).join; 
	} 
	
	alias FbResultSet = FbDatabase.Transaction.ResultSet; 
	
	enum TableStyle : ubyte
	{hex, json, csv, txt, struct_, struct_hdr, struct_data, struct_hdr_ex, ascii, ansi, ansi_thick, ansi_round, turbo, norton} 
	
	TableStyle toTableStyle(string s)()
	=> ((sameText(s, "struct"))?(TableStyle.struct_):(s.lc.to!TableStyle)); 
	
	string formatTable(string style="json")(auto ref FbResultSet rows, TableStyle style=toTableStyle!style)
	{
		if(!rows.fields) return ""; 
		/+
			rows: This range returns an FbFields reference containing the binary data of the 
			most recent fetched row, and all the metadata in `xsqlda` / `vars[]`.
		+/
		auto vars = rows.fields.vars; 
		
		version(/+$DIDE_REGION Result string building+/all)
		{
			auto res = appender!string; 
			void appendStr(string s) { res ~= s; } 
			void appendLine(string s) { res ~= ((res.empty)?(""):("\n"))~s; } 
		}
		
		
		
		void appendSeparatedRow(string varField, string delim, string invalidChars)()
		{
			string quoteIfNeeded(string s)
			=> ((
				s.map!(
					iq{
						a<32 || a.among(
							'"', '\'', '`' $(
								((invalidChars!="")?(","):(""))
								~ invalidChars
							)
						)
					}.text
				).any
			) ?(s.quoted):(s)); 
			appendLine(mixin(求map(q{v},q{vars},q{quoteIfNeeded(mixin("v."~varField))})).join(delim)); 
		} 
		
		static struct GridStyle { string[3] horiz; string[3][3] box; string[3] vert; string[2][2] pad; } 
		void formatGrid(in GridStyle g)
		{
			auto 	isNumeric 	= vars.map!((v)=>(v.isSomeNumber)).array,
				data 	= [vars.map!((v)=>(v.aliasName)).array],
				widths 	= data[0].map!"a.length".array; 
			
			foreach(row; rows) {
				auto line = vars.map!((v)=>(v.toPlainText)).array; data ~= line; 
				foreach(i, s; line) widths[i].maximize(s.length); 
			}
			
			string padCell(string s, size_t w, bool alignRight)
			=> ((alignRight)?(s.padLeft(' ', w).text):(s.padRight(' ', w).text)); 
			
			void appendRow(string[] data, bool header=false)
			{
				appendLine(
					g.vert[0] ~ (
						iota(data.length).map!
						((i)=>(
							g.pad[1-header][0]~
							padCell(
								data[i], widths[i], 
								isNumeric[i]&~header
							)~
							g.pad[1-header][1]
						)).join(g.vert[1])
					) ~ g.vert[2]
				); 
			} 
			
			string buildHLine(int i)
			=> g.box[i][0] ~ widths.map!((w)=>(g.horiz[i].replicate(w))).join(g.box[i][1]) ~ g.box[i][2]; 
			const hLines = iota(3).map!buildHLine.array; 
			
			appendLine(hLines[0]); appendRow(data[0], header: true); 
			appendLine(hLines[1]); data[1..$].each!appendRow; appendLine(hLines[2]); 
		} 
		
		void appendStructDefinition(R1, R2, R3, R4)(
			string relName, string structName, 
			R1 fieldTypes, R2 origFieldNames, R3 fieldNames, R4 comments
		)
		{
			appendLine(i"@$(relName.quoted) struct $(structName)".text); 
			appendLine("{"); 
				foreach(orig, type, name, comment; zip(origFieldNames, fieldTypes, fieldNames, comments))
			appendLine(i"\t@$(orig.quoted) $(type) $(name);$(comment)".text); 
			appendLine("}"); 
		} 
		
		final switch(style)
		{
			case mixin(舉!((TableStyle),q{hex})): 	{ foreach(row; rows) appendLine(row.dataBuf.hexDump); }	break; 
			case mixin(舉!((TableStyle),q{json})): 	{
				appendLine("["); bool running; 
				foreach(row; rows)
				{
					if(!running.chkSet) appendStr(","); 
					const jsonField =
					mixin(求map(q{v},q{vars},q{i"\t\t$(v.aliasName.quoted)\t: $(v.toJsonText)".text})).join(",\n"); 
					appendLine("\t{\n" ~ jsonField ~ "\n\t}"); 
				}
				appendLine("]"); 
			}	break; 
			case mixin(舉!((TableStyle),q{csv})): 	{
				alias doit(string v) = appendSeparatedRow!(v, ";", q{';', ','}); 
				doit!q{aliasName}; foreach(row; rows) doit!q{toPlainText}; 
			}	break; 	
			case mixin(舉!((TableStyle),q{txt})): 	{
				alias doit(string v) = appendSeparatedRow!(v, "\t", q{}); 
				doit!q{aliasName}; foreach(row; rows) doit!q{toPlainText}; 
			}	break; 
			case mixin(舉!((TableStyle),q{struct_})),
			mixin(舉!((TableStyle),q{struct_hdr})),
			mixin(舉!((TableStyle),q{struct_data})),
			mixin(舉!((TableStyle),q{struct_hdr_ex})): 	{
				auto 	relName 	= vars.front.relName,
					structName 	= vars.front.tableIdentifier,
					origFieldNames 	= vars.enumerate.map!((a)=>(a.value.aliasName)).array,
					fieldNames 	= vars.enumerate.map!((a)=>(a.value.fieldIdentifier(a.index))).array,
					fieldTypes	= vars.map!((v)=>(v.DType)).array; 
				if(style==mixin(舉!((TableStyle),q{struct_hdr_ex})))
				{
					auto examples = new string[][vars.length]; 
					foreach(row; rows) foreach(i, var; vars) examples[i] ~= var.DLiteral; 
					auto comments = examples.map!
						((e)=>(
						i"\t/+Structured:$(chain(e, only("...")).join(", ")
.safeDCommentBody)+/".text
					)).array; 
					appendStructDefinition(
						relName, structName, 
						fieldTypes, origFieldNames, fieldNames, comments
					); 
				}
				else
				{
					const hasHeader = style!=mixin(舉!((TableStyle),q{struct_data})), hasData = style!=mixin(舉!((TableStyle),q{struct_hdr})); 
					if(hasHeader)
					appendStructDefinition(
						relName, structName, 
						fieldTypes, origFieldNames, fieldNames, "".repeat
					); 
					if(hasData)
					{
						appendLine("["); bool running; 
						foreach(row; rows)
						{
							if(!running.chkSet) appendStr(","); 
							appendLine(i"\t$(structName)(".text); 
							foreach(i, v; vars)
							{
								if(i) appendStr(","); 
								appendLine(i"\t\t$(fieldNames[i]): $(v.DLiteral)".text); 
							}
							appendLine("\t)"); 
						}
						appendLine("]"); 
					}
				}
			}	break; 
			
			case mixin(舉!((TableStyle),q{ascii})): 	{
				formatGrid(
					GridStyle(
						[
							"-",
							"-",
							"-"
						],	[
							["+-","-+-","-+"],
							["+-","-+-","-+"],
							["+-","-+-","-+"]
						],
							  ["| "," | "," |"]
					)
				); 
			}	break; 
			case mixin(舉!((TableStyle),q{ansi})): 	{
				formatGrid(
					GridStyle(
						[
							"─",
							"─",
							"─"
						],	[
							["┌─","─┬─","─┐"],
							["├─","─┼─","─┤"],
							["└─","─┴─","─┘"]
						],
							  ["│ "," │ "," │"]
					)
				); 
			}	break; 
			case mixin(舉!((TableStyle),q{ansi_thick})): 	{
				formatGrid(
					GridStyle(
						[
							"═",
							"─",
							"═"
						],	[
							["╔═","═╤═","═╗"],
							["╟─","─┼─","─╢"],
							["╚═","═╧═","═╝"]
						],
							  ["║ "," │ "," ║"]
					)
				); 
			}	break; 
			case mixin(舉!((TableStyle),q{ansi_round})): 	{
				formatGrid(
					GridStyle(
						[
							"─",
							"─",
							"─"
						],	[
							["╭─","─┬─","─╮"],
							["├─","─┼─","─┤"],
							["╰─","─┴─","─╯"]
						],
							  ["│ "," │ "," │"]
					)
				); 
			}	break; 
			case mixin(舉!((TableStyle),q{turbo})): 	{
				const f = "\34\7\33\0", d = "\34\0\33\7"; 
				formatGrid(
					GridStyle(
						[
							"─",
							"─",
							"─"
						],	[
							[f~" ┌─","─┬─","─┐ "~d],
							[f~" ├─","─┼─","─┤ "~d],
							[f~" └─","─┴─","─┘ "~d]
						],
							  [f~" │ "," │ "," │ "~d],
						[["\33\1","\33\0"],["",""]]
					)
				); 
			}	break; 
			case mixin(舉!((TableStyle),q{norton})): 	{
				const f = "\34\1\33\13", d = "\34\0\33\7"; 
				formatGrid(
					GridStyle(
						[
							"═",
							"─",
							"═"
						],	[
							[f~"╔","╤","╗"~d],
							[f~"╟","┼","╢"~d],
							[f~"╚","╧","╝"~d]
						],
							  [f~"║","│","║"~d],
						[["\33\16","\33\13"],["",""]]
					)
				); 
			}	break; 
		}
		
		return res[]; 
	} 
	
	version(/+$DIDE_REGION+/all) {
		T[] toStructArray(T)(auto ref FbResultSet rows, bool strict = true, string FILE = __FILE__, size_t LINE = __LINE__)
		{
			try
			{
				if(!rows.fields) return []; auto vars = rows.fields.vars; 
				
				enum structFieldNames = [FieldNamesWithUDA!(T, STORED, true)]; 
				const 	varFieldNames = vars.enumerate.map!((a)=>(a.value.fieldIdentifier(a.index))).array,
					colIdx = structFieldNames.map!
						((sName){
					const vIdx = varFieldNames.countUntil!sameText(sName); 
					enforce(
						!strict || vIdx>=0, 
						i"Missing column for field $(sName)".text
					); return vIdx; 
				}).array; 
				
				auto res = appender!(T[]); 
				foreach(row; rows)
				{
					T item; 
					static foreach(i, name; structFieldNames)
					{
						if(colIdx[i]>=0)
						{
							alias FieldT = typeof(__traits(getMember, item, name)); 
							__traits(getMember, item, name) = vars[colIdx[i]].readValue!FieldT; 
						}
					}
					res ~= item; 
				}
				return res[]; 
			}
			catch(Exception e) { enforce(0, e.simpleMsg, FILE, LINE); assert(0); }
		} 
		T[] toArray(T)(auto ref FbResultSet rows, bool strict = true, string FILE = __FILE__, size_t LINE = __LINE__)
		{
			enum isValue = __traits(compiles, { XSQLVAR v; auto x = v.readValue!T; }); 
			static if(!isValue)
			{ return toStructArray!T(rows, strict, FILE, LINE); }
			else
			{
				try
				{
					if(!rows.fields) return []; auto vars = rows.fields.vars; 
					enforce(rows.fields.length>=1, "No columns in FbResultSet."); 
					
					auto res = appender!(T[]); 
					foreach(row; rows) res ~= vars[0].readValue!T; 
					return res[]; 
				}
				catch(Exception e) { enforce(0, e.simpleMsg, FILE, LINE); assert(0); }
			}
		} 
	}
	
	
	
	/+
		Prompt for AI to discover relationships:
		
		/+
			Code: string prompt; 
			foreach(table; tables)
			{
				prompt ~= 	(查((位!()),iq{},iq{SELECT * FROM $(Literal(table)) ROWS 3}))
					.formatTable!"struct_hdr_ex"~"\n\n"; 
			}
		+/
		
		/+
			User: /+
				Code: struct EmployeeDatabase
				{
					/+
						Notes: 
						 *	Each struct here represents a database table or view.
						 *	The user defined attributes are representing the original SQL identifiers: @"FIELD"
						 *	The field names in the structs are proper DLang identifiers.
						 *	There are additional examples after the fields in the comments to help 
							identify the meaning of each field.
					+/
					
					/+
						Your task is to examine the structure of this database schema, and make a list of 
						relations between the tables!
						Example output:
						/+
							Code: struct Relationship {
								bool isNullable; 
								string fromTable; string[] fromFields; 
								string toTable; string[] toFields; 
							} 
							static immutable _relationships =
							[
								Relationship(false, "CUSTOMER", ["COUNTRY"], "COUNTRY", ["COUNTRY"]),
								Relationship(true, "EMPLOYEE", ["DEPT_NO"], "DEPARTMENT", ["DEPT_NO"]),
								Relationship(
									false, "EMPLOYEE", [
										"JOB_CODE", 
										"JOB_GRADE", 
										"JOB_COUNTRY"
									], "JOB", [
										"JOB_CODE",
										"JOB_GRADE", 
										"JOB_COUNTRY"
									]
								)
								/+and so on+/
							]; 
						+/
						
						Also please make an order to load the tables optimally, 
						put the tables in the front where there are minimal connections going towards other tables!
						It must be not perfect because circular references are allowed, but should be quite optimal.
						Example:
						/+Code: static immutable _loadOrder = ["COUNTRY", ..., "SALES"]; +/
					+/
					
					/+header_ex comes here!!!!!!!!!!!!!+/
				} 
			+/
		+/
	+/
	
	
	void test_makeDBSchema()
	{
		auto dbFaszom = new FbDatabase(
			`c:\Program Files\Firebird\Firebird_2_5\examples\empbuild\EMPLOYEE.FDB`, 
			"SYSDBA", "masterkey"
		); 
		scope(exit) dbFaszom.free; 
		static if((常!(bool)(0)))
		with(DBSchemaImporter(dbFaszom))
		{
			foreach(tableName; db.allTablesAndViews)
			(查((位!()),iq{},iq{SELECT * FROM $(tableName.Literal)})); 
		}
		
		
		/+
			
			
			with(db) {
				allTablesAndViews.map!((a)=>(fetchTable(a).formatTable!"txt")).join("\n").saveTo(`c:\dl\b.b`); 
				db.fetchHeaders.saveTo(`c:\dl\a.a`); 
				
				struct PrimaryKey { string constraint, table; string[] fields; } 
				struct ForeignKey { string constraint, srcTable, dstTable; string[] srcFields, dstFields; } 
				PrimaryKey[] pk; 
				with(transaction)
				{
					foreach(
						row; (查 ((位!()),iq{},iq{
							SELECT
								rc.rdb$constraint_name 	AS "constraint",
								iseg.rdb$field_position 	AS "position",
								rc.rdb$relation_name	AS "table",
								iseg.rdb$field_name	AS "field"
							FROM rdb$relation_constraints rc
							JOIN rdb$index_segments iseg
								ON iseg.rdb$index_name = rc.rdb$index_name
							WHERE rc.rdb$constraint_type = `PRIMARY KEY`
							ORDER BY rc.rdb$relation_name, iseg.rdb$field_position
						}))
					)
					{
						const 	constraint 	= row.constraint.to!string,
							position 	= row.position.to!int,
							table 	= row.table.to!string,
							field 	= row.field.to!string; 
						if(position==0)	pk ~= PrimaryKey(constraint, table); 
						pk.back.fields ~= field; 
					}
					ForeignKey[] fk; 
					foreach(
						row; (查 ((位!()),iq{},iq{
							SELECT
								rc.rdb$constraint_name 	AS "constraint",
								iseg.rdb$field_position	AS "position",
								rc.rdb$relation_name	AS "srcTable",
								iseg.rdb$field_name	AS "srcField",
								rc2.rdb$relation_name	AS "dstTable",
								iseg2.rdb$field_name	AS "dstField"
							FROM rdb$relation_constraints rc
							JOIN rdb$ref_constraints ref
								ON ref.rdb$constraint_name = rc.rdb$constraint_name
							JOIN rdb$relation_constraints rc2
								ON rc2.rdb$constraint_name = ref.rdb$const_name_uq
							JOIN rdb$index_segments iseg
								ON iseg.rdb$index_name = rc.rdb$index_name
							JOIN rdb$index_segments iseg2
								ON iseg2.rdb$index_name = rc2.rdb$index_name
								AND iseg2.rdb$field_position = iseg.rdb$field_position
							WHERE rc.rdb$constraint_type = `FOREIGN KEY`
							ORDER BY rc.rdb$relation_name, iseg.rdb$field_position
						}))
					)
					{
						const 	constraint 	= row.constraint.to!string,
							position 	= row.position.to!int,
							srcTable 	= row.srcTable.to!string,
							srcField 	= row.srcField.to!string,
							dstTable 	= row.dstTable.to!string,
							dstField 	= row.dstField.to!string;  
						if(position==0) fk ~= ForeignKey(constraint, srcTable, dstTable); 
						ref a = fk.back; 
						enforce(a.srcTable==srcTable && a.dstTable==dstTable); 
						a.srcFields ~= srcField, a.dstFields ~= dstField; 
					}
					pk.each!print; 
					fk.each!print; 
				}
				
			}
			
			
			
		+/
		if((常!(bool)(0))) { console.hide; }
		if((常!(bool)(0))) { application.exit; }
	} 
}