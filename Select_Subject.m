clear
clc

load('All_sFile_epochs.mat');

% Start a new report
bst_report('Start', sFiles);

% Process: Select file paths with tag: Subject_0371
sFiles = bst_process('CallProcess', 'process_select_tag', sFiles, [], ...
    'tag',    'Subject_0820', ...
    'search', 1, ...  % Search the file paths
    'select', 1);  % Select only the files with the tag

% Save and display report
ReportFile = bst_report('Save', sFiles);
bst_report('Open', ReportFile);