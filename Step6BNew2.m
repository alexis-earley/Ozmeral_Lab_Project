function Step6BNew2(sourceFolder, destFolder)
% Creates subject-level averages for each condition and trigger.
% Uses channel-wise weights from num_files(63x1) for improved robustness.

    if ~exist(destFolder, 'dir')
        mkdir(destFolder); % Make destination folder if needed
    end

    files = dir(fullfile(sourceFolder, '*.mat')); % Get list of MATLAB files

    for i = 1:length(files)
        outputStruct = struct();  % Clear for each subject

        fileName = files(i).name;
        disp(['Loading file: ', fileName]); % Shows progress

        subjectStruct = load(fullfile(sourceFolder, fileName));
        subjectName = fieldnames(subjectStruct); % Like 'Subject_0170_6A'
        subjectTag = subjectName{1};
        subjectStruct = subjectStruct.(subjectTag); % Dereference top-level field

        allSubjStruct = struct(); % Will hold all averaged data

        conditions = fieldnames(subjectStruct);
        for j = 1:length(conditions)
            condition = conditions{j}; % e.g., Attend30R
            condStruct = subjectStruct.(condition);

            triggerNames = fieldnames(condStruct);
            for k = 1:length(triggerNames)
                triggerName = triggerNames{k}; % e.g., trigger_1_N
                triggerStruct = condStruct.(triggerName);

                fileNames = fieldnames(triggerStruct);
                for l = 1:length(fileNames)
                    fileNameInner = fileNames{l};
                    fileStruct = triggerStruct.(fileNameInner);

                    epochNames = fieldnames(fileStruct);
                    for m = 1:length(epochNames)
                        epochName = epochNames{m};

                        % Unpack expected fields from this file
                        epochMatrix = fileStruct.(epochName).epoch_avg;
                        channelWeights = fileStruct.(epochName).num_files;

                        try
                        allSubjStruct = accumulate_weighted_matrix(allSubjStruct, condition, triggerName, fileNameInner, epochMatrix, channelWeights);
                        catch
                            disp(['Skipping due to mismatch: ', fileNameInner, ' in ', condition, ' / ', triggerName]);
                            continue;
                        end
                    end
                end
            end
        end

        % Finalize weighted averages for each field
        subjConds = fieldnames(allSubjStruct);
        for j = 1:length(subjConds)
            condition = subjConds{j};
            triggerList = fieldnames(allSubjStruct.(condition));

            for k = 1:length(triggerList)
                triggerName = triggerList{k};
                fileList = fieldnames(allSubjStruct.(condition).(triggerName));

                for l = 1:length(fileList)
                    fname = fileList{l};
                    numMat = allSubjStruct.(condition).(triggerName).(fname).num_files;
                    sumMat = allSubjStruct.(condition).(triggerName).(fname).epoch_avg;

                    % Divide each row (channel) by valid count
                    finalAvg = zeros(size(sumMat));
                    for ch = 1:size(sumMat, 1)
                        count = numMat(ch);
                        if count > 0
                            finalAvg(ch, :) = sumMat(ch, :) / count;
                        end
                    end

                    % Store final output
                    allSubjStruct.(condition).(triggerName).(fname).epoch_avg = finalAvg;
                    allSubjStruct.(condition).(triggerName).(fname).num_files = numMat;
                end
            end
        end

        % Save new file
        outputTag = [erase(subjectTag, '_6A') '_6B'];
        outputStruct.(outputTag) = allSubjStruct;
        save(fullfile(destFolder, [outputTag '.mat']), '-struct', 'outputStruct', '-v7.3');
        disp(['Saved output to: ', fullfile(destFolder, [outputTag '.mat'])]);
    end
end

function allSubjsStruct = accumulate_weighted_matrix(allSubjsStruct, condition, triggerName, fileName, epochMatrix, weightVec)
% Accumulates weighted matrix values and valid channel counts

    if ~isfield(allSubjsStruct, condition)
        allSubjsStruct.(condition) = struct();
    end
    condStruct = allSubjsStruct.(condition);

    if ~isfield(condStruct, triggerName)
        condStruct.(triggerName) = struct();
    end
    triggerStruct = condStruct.(triggerName);

    if ~isfield(triggerStruct, fileName)
        % First time adding this entry
        triggerStruct.(fileName).epoch_avg = epochMatrix .* weightVec; % weight per channel
        triggerStruct.(fileName).num_files = weightVec;
    else
        % Add to existing entry
        prevSum = triggerStruct.(fileName).epoch_avg;
        prevWeights = triggerStruct.(fileName).num_files;
        
        
        if ~isequal(size(prevSum), size(epochMatrix))
            error('Size mismatch');
        end
        

        triggerStruct.(fileName).epoch_avg = prevSum + epochMatrix .* weightVec;
        triggerStruct.(fileName).num_files = prevWeights + weightVec;
    end

    condStruct.(triggerName) = triggerStruct;
    allSubjsStruct.(condition) = condStruct;
end