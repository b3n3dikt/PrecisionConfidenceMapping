function [SUB, SES, TASK] = extract_sub_ses_task_from_path(infile)
    % Regular expression to extract SUB, SES, and TASK
    subPattern = 'sub-([a-zA-Z0-9]+)';
    sesPattern = 'ses-([^/]+)';
    taskPattern = 'task-([^_]+)';

    % Extract SUB
    subToken = regexp(infile, subPattern, 'tokens');
    if ~isempty(subToken)
        SUB = subToken{1}{1};
    else
        error('Subject ID could not be extracted.');
    end

    % Extract SES
    sesToken = regexp(infile, sesPattern, 'tokens');
    if ~isempty(sesToken)
        SES = sesToken{1}{1};
    else
        error('Session ID could not be extracted.');
    end

    % Extract TASK
    taskToken = regexp(infile, taskPattern, 'tokens');
    if ~isempty(taskToken)
        TASK = taskToken{1}{1};
    else
        error('Task ID could not be extracted.');
    end
end


%function [SUB, SES, TASK] = extract_sub_ses_task_from_path(infile)
%    % Regular expression to extract SUB, SES, and TASK
%    subPattern = 'sub-(\d+)';
%    % Updated pattern to stop at the first slash after 'ses-'
%    sesPattern = 'ses-([^/]+)';
%    taskPattern = 'task-([^_]+)';
%
%    % Extract SUB
%    subToken = regexp(infile, subPattern, 'tokens');
%    if ~isempty(subToken)
%        SUB = subToken{1}{1};
%    else
%        error('Subject ID could not be extracted.');
%    end
%
%    % Extract SES
%    sesToken = regexp(infile, sesPattern, 'tokens');
%    if ~isempty(sesToken)
%        SES = sesToken{1}{1};
%    else
%        error('Session ID could not be extracted.');
%    end
%
%    % Extract TASK
%    taskToken = regexp(infile, taskPattern, 'tokens');
%    if ~isempty(taskToken)
%        TASK = taskToken{1}{1};
%    else
%        error('Task ID could not be extracted.');
%    end
%end
