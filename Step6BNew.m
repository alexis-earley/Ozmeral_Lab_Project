function Step6BNew(sourceFolder, destFolder) % Input and output should be directories

    if ~exist(destFolder, 'dir')
        mkdir(destFolder); % Make destination folder
    end
    files = dir(fullfile(sourceFolder, '*.mat')); % Get list of MATLAB files

    % Loop over each file (each subject)
    for i = 1:length(files)
        outputStruct = struct();  % Clear per subject

        fileName = files(i).name;
        disp(['Loading file: ', fileName]); % Shows progress

        subjectStruct = load(fullfile(sourceFolder, fileName)); % Load subject file
        subjectName = fieldnames(subjectStruct); % Like 'Subject_0604'
        subjectTag = subjectName{1};  % For final wrapping
        subjectStruct = subjectStruct.(subjectTag); % Get top-level struct

        allSubjStruct = struct();  % Struct to accumulate averaged data

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
                    innerFile = fileNames{l}; % Like trigger_4_N
                    fileStruct = triggerStruct.(innerFile);

                    epochNames = fieldnames(fileStruct);
                    for m = 1:length(epochNames)
                        epochName = epochNames{m}; % Like epoch_1
                        epochMatrix = fileStruct.(epochName); % Data matrix

                        try
                            allSubjStruct = accumulate_matrix(allSubjStruct, condition, triggerName, innerFile, epochMatrix);
                        catch
                            disp(['Skipping file due to error: ', innerFile, ' in condition ', condition, ', trigger ', triggerName]);
                            continue;
                        end
                    end
                end
            end
        end

        % Final averaging across all triggers
        subjList = fieldnames(allSubjStruct);
        for j = 1:length(subjList)
            condition = subjList{j};
            triggerList = fieldnames(allSubjStruct.(condition));

            for k = 1:length(triggerList)
                triggerName = triggerList{k};
                fileList = fieldnames(allSubjStruct.(condition).(triggerName));

                for l = 1:length(fileList)
                    fName = fileList{l};
                    fileCount = allSubjStruct.(condition).(triggerName).(fName).num_files;
                    dataSum = allSubjStruct.(condition).(triggerName).(fName).epoch_avg;
                    allSubjStruct.(condition).(triggerName).(fName).epoch_avg = dataSum / fileCount;
                end
            end
        end

        % Wrap and save under modified subject name
        outputTag = [erase(subjectTag, '_6A') '_6B'];
        outputStruct.(outputTag) = allSubjStruct;
        savePath = fullfile(destFolder, [outputTag '.mat']);
        save(savePath, '-struct', 'outputStruct', '-v7.3');
        disp(['Saved averaged file to: ', savePath]);
    end
end

function allSubjsStruct = accumulate_matrix(allSubjsStruct, condition, triggerName, fileName, epochMatrix)

    if ~isfield(allSubjsStruct, condition)
        allSubjsStruct.(condition) = struct();
    end
    condStruct = allSubjsStruct.(condition);

    if ~isfield(condStruct, triggerName)
        condStruct.(triggerName) = struct();
    end
    triggerStruct = condStruct.(triggerName);

    if ~isfield(triggerStruct, fileName)
        fileStruct.epoch_avg = epochMatrix;
        fileStruct.num_files = 1;
    else
        fileStruct = triggerStruct.(fileName);
        if ~isequal(size(fileStruct.epoch_avg), size(epochMatrix))
            disp(['Expected: ', mat2str(size(fileStruct.epoch_avg)), ...
                  ', Got: ', mat2str(size(epochMatrix))]);
            error('Dimension mismatch.');
        end
        fileStruct.epoch_avg = fileStruct.epoch_avg + epochMatrix;
        fileStruct.num_files = fileStruct.num_files + 1;
    end

    triggerStruct.(fileName) = fileStruct;
    condStruct.(triggerName) = triggerStruct;
    allSubjsStruct.(condition) = condStruct;
end
