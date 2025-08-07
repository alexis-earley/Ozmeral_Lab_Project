function sFiles = SelectUsingTag(sFiles, tag)

% Select all sFiles with a specific tag

tag = char(tag); 

disp(['Selecting files using tag: ', tag, '.']);

sFiles = bst_process('CallProcess', 'process_select_tag', sFiles, [], ...
    'tag',    tag, ...   % OR logic: cell array of tags
    'search', 1, ...  % Search the file paths
    'select', 1);  % Select files with any of the tags

% Display how many files were selected
disp([num2str(length(sFiles)), ' files selected.']);

end
