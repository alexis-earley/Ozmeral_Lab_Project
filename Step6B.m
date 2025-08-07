function Step6B(sourceFolder, destFolder) % Input and output should be directories

    if ~exist(destFolder, 'dir')
        mkdir(destFolder); % Make destination folder
    end
    files = dir(fullfile(sourceFolder, '*.mat')); % Get list of MATLAB files

    allSubjStruct = struct(); % Initialize single output struct

    % Loop over each file
    for i = 1:length(files)
        fileName = files(i).name;
        disp(['Loading file: ', fileName]); % Shows progress because this takes a while

        subjectStruct = load(fullfile(sourceFolder, fileName)); % Load file, which has single struct
        subjectName = fieldnames(subjectStruct); % Like Subject_0604'
        subjectStruct = subjectStruct.(char(subjectName)); % Make struct equal to that top field to make things cleaner
        % Note now subjectStruct has fields: conditions -> triggers -> file names -> epochs

        conditions = fieldnames(subjectStruct);
        for j = 1:length(conditions)
            condition = conditions{j}; % Like PassiveN
            condStruct = subjectStruct.(condition);

            triggerNames = fieldnames(condStruct);
            for k = 1:length(triggerNames)
                triggerName = triggerNames{k}; % Like Attend60L
                triggerStruct = condStruct.(triggerName);

                fileNames = fieldnames(triggerStruct);
                for l = 1:length(fileNames)
                    fileName = fileNames{l}; % Like trigger_4_N
                    fileStruct = triggerStruct.(fileName);

                    epochNames = fieldnames(fileStruct);
                    for m = 1:length(epochNames)
                        epochName = epochNames{m}; % Like epoch_1
                        epochMatrix = fileStruct.(epochName); % Data matrix

                        try
                            allSubjStruct = accumulate_matrix(allSubjStruct, condition, triggerName, fileName, epochMatrix);
                        catch
                            disp(['Skipping file due to error: ', fileName, ' in condition ', condition, ', trigger ', triggerName]);
                            continue;
                        end
                    end
                end
            end
        end

        clear subjectStruct; % Keeps memory from overloading
    end

    % Final averaging across all triggers
    subjList = fieldnames(allSubjStruct);
    for i = 1:length(subjList)
        condition = subjList{i};
        triggerList = fieldnames(allSubjStruct.(condition));

        for j = 1:length(triggerList)
            triggerName = triggerList{j};
            fileList = fieldnames(allSubjStruct.(condition).(triggerName));

            for k = 1:length(fileList)
                fileName = fileList{k};
                fileCount = allSubjStruct.(condition).(triggerName).(fileName).num_files;
                dataSum = allSubjStruct.(condition).(triggerName).(fileName).epoch_avg; 
                allSubjStruct.(condition).(triggerName).(fileName).epoch_avg = dataSum / fileCount; % This is the averaging!
            end
        end
    end

    % Save result
    outputFileName = fullfile(destFolder, 'All_Subjects.mat');
    save(outputFileName, 'allSubjStruct', '-v7.3');
    disp(['Saved averaged data to: ', outputFileName]);
end

function allSubjsStruct = accumulate_matrix(allSubjsStruct, condition, triggerName, fileName, epochMatrix)
    
    if ~isfield(allSubjsStruct, condition) % Initialize if needed
        allSubjsStruct.(condition) = struct();
    end
    condStruct = allSubjsStruct.(condition);

    if ~isfield(condStruct, triggerName)
        condStruct.(triggerName) = struct();
    end
    triggerStruct = condStruct.(triggerName);

    if ~isfield(triggerStruct, fileName) % Lower level does not exist/have at least one field
        fileStruct.epoch_avg = epochMatrix; % Intialize with field
        fileStruct.num_files = 1;
    else % Add field to list and increment number of files
        fileStruct = triggerStruct.(fileName);
        if ~isequal(size(fileStruct.epoch_avg), size(epochMatrix))
            disp(['Expected: ', mat2str(size(fileStruct.epoch_avg)), ...
          ', Got: ', mat2str(size(epochMatrix))]);
            error('Dimension mismatch.');
        end
        fileStruct.epoch_avg = fileStruct.epoch_avg + epochMatrix;
        fileStruct.num_files = fileStruct.num_files + 1;
    end

    % Write back all levels, building up to allSubjsStruct
    triggerStruct.(fileName) = fileStruct;
    condStruct.(triggerName) = triggerStruct;
    allSubjsStruct.(condition) = condStruct;
end
