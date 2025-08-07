function sFilesNew = SelectFiles()

% Selects all sFiles within the currently loaded protocol 

% Get all protocol studies
sAllStudies = bst_get('ProtocolStudies');

% Initialize empty list
sFiles = [];

% Loop through all studies
for i = 1:length(sAllStudies.Study)
    currStudy = sAllStudies.Study(i);
    if isfield(currStudy, 'Data') && ~isempty(currStudy.Data)
        sFiles = [sFiles, currStudy.Data];  % Append data files
    end

    % Display progress every 500 iterations
    if mod(i, 500) == 0
        disp([num2str(i), ' sFile folders loaded']);
    end
end

disp('Converting sFiles to proper format. This may take up to 5 minutes if there are 100k+ files.')

sFileNames = {sFiles.FileName};

tic

% Converts to proper format by selecting all files with dashes (should be
% all files) the traditional Brainstorm programming way
sFilesNew = bst_process('CallProcess', 'process_select_tag', sFileNames, [], ...
    'tag',    '_', ...
    'search', 1, ...  % Search the file paths
    'select', 1);  % Select only the files with the tag

elapsedTime = toc;
% Display total number of files loaded
disp(['A total of ', num2str(length(sFiles)), ' sFiles were loaded.']);
disp(['Elapsed time for converting format: ', num2str(elapsedTime), ' seconds']);

end
