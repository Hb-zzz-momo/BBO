function suite_log = rac_begin_suite_logging(result_dir, suite_cfg, suite_name)
% rac_begin_suite_logging
% Initialize suite-scoped log file and lock lifecycle.

    suite_log = struct();
    suite_log.file = fullfile(result_dir.logs, 'run_log.txt');
    suite_log.lock_dir = fullfile(result_dir.logs, 'run_log.lockdir');

    [lock_ok, lock_msg, lock_msg_id] = mkdir(suite_log.lock_dir);
    if ~lock_ok
        error('CECRunner:LogLockBusy', 'Cannot acquire run log lock: %s (%s:%s)', suite_log.lock_dir, lock_msg_id, lock_msg);
    end

    reset_fid = fopen(suite_log.file, 'w');
    if reset_fid < 0
        error('CECRunner:LogResetFailed', 'Cannot reset run log file: %s', suite_log.file);
    end
    fclose(reset_fid);

    rac_log_message(suite_log.file, sprintf('Start experiment: %s', suite_cfg.experiment_name));
    rac_log_message(suite_log.file, sprintf('Suite: %s', suite_name));
    rac_log_message(suite_log.file, sprintf('Primary budget maxFEs: %d', suite_cfg.maxFEs));

    lock_dir = suite_log.lock_dir;
    suite_log.cleanup = onCleanup(@() local_release_log_lock(lock_dir));
end

function local_release_log_lock(lock_dir)
    if isfolder(lock_dir)
        rmdir(lock_dir, 's');
    end
end
