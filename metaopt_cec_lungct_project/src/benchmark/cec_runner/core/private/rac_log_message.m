function rac_log_message(log_file, msg)
    timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
    line = sprintf('[%s] %s\n', timestamp, msg);

    fid = fopen(log_file, 'a');
    if fid < 0
        error('Cannot open log file: %s', log_file);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', line);
end
