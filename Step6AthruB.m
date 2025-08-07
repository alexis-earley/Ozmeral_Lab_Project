function Step6AthruB(sourceFolder, destFolder, mvLimit)
    if ~exist(destFolder, 'dir')
        mkdir(destFolder);
    end

    files = dir(fullfile(sourceFolder, '*.mat'));
    totalGood = 0;
    totalBad = 0;

    subjectMaxDict = containers.Map();
    subjectStats = containers.Map();   

    for j = 1:length(files)
        fileName = files(j).name;
        sourcePath = fullfile(sourceFolder, fileName);

        [~, nameOnly, ~] = fileparts(fileName);
        outputTag = [nameOnly '_6AB'];
        destinationPath = fullfile(destFolder, [outputTag '.mat']);

        disp(['Processing file: ', fileName]);

        data = load(sourcePath);
        varName = fieldnames(data);
        topVarName = varName{1};
        structData = data.(topVarName);
        disp(['Loaded struct variable: ', topVarName]);

        newStructData = struct();
        modifiedCount = 0;
        subjGood = 0;
        subjBad = 0;
        subjMaxList = [];

        condNames = fieldnames(structData);
        for i = 1:length(condNames)
            condition = condNames{i};
            triggerNames = fieldnames(structData.(condition));
            for j2 = 1:length(triggerNames)
                trigger = triggerNames{j2};
                blockNames = fieldnames(structData.(condition).(trigger));
                for k = 1:length(blockNames)
                    block = blockNames{k};

                    sumMat = zeros(63, 1051);
                    sumWeights = zeros(63, 1);

                    epochNames = fieldnames(structData.(condition).(trigger).(block));
                    for m = 1:length(epochNames)
                        epoch = epochNames{m};
                        matrix = structData.(condition).(trigger).(block).(epoch);

                        if ~all(isfinite(matrix(:)))
                            error('Non-finite values found in channel.');
                        end

                        if isnumeric(matrix) && ismatrix(matrix)
                            nRows = size(matrix, 1);
                            if nRows == 63
                                reducedChannels = matrix;
                            elseif nRows == 70 || nRows == 88
                                rowsToDelete = [32, 65:nRows];
                                reducedChannels = matrix(setdiff(1:nRows, rowsToDelete), :);
                                modifiedCount = modifiedCount + 1;
                            elseif nRows == 69
                                rowsToDelete = [64:nRows];
                                reducedChannels = matrix(setdiff(1:nRows, rowsToDelete), :);
                                modifiedCount = modifiedCount + 1;
                            else
                                error(['Matrix "', epoch, '" has ', num2str(nRows), ...
                                    ' rows (expected 63, 69, 70, or 88).']);
                            end

                            stdLimit = 6.5;

                            channelStd = std(reducedChannels, 0, 2);  % Std deviation across time for each channel
                            meanStd = mean(channelStd, 'omitnan');
                            stdOfStd = std(channelStd, 'omitnan');       
                            zScores = abs(channelStd - meanStd) / stdOfStd;
                            passMatrixStd = double(zScores <= stdLimit);  % stdLimit typically 3
                            %exceedIdxStd = find(zScores > stdLimit);  % Bad channels

                            flatThresh = 5e-8;  % Adjust as needed
                            passMatrixActive = double(channelStd >= flatThresh);  % 1 = not flat, 0 = flat
               
                            channelsMax = max((reducedChannels), [], 2);
                            channelsMin = min((reducedChannels), [], 2);
                            channelsDiff = channelsMax - channelsMin;
                            mvChannelsDiff = channelsDiff * 1e6;
                            passMatrixDiff = double(mvChannelsDiff <= mvLimit);

                            %exceedIdxMax = find(mvChannelsDiff > mvLimit);
                            
                            %{
                            if any(passMatrixActive == 0)
                                disp('Flat channels detected.');
                                
                                figure;
                                hold on;
                                exceedIdxActive = find(passMatrixActive == 0);
                                for ch = 1:size(reducedChannels, 1)
                                    if ismember(ch, exceedIdxActive)
                                        plot(reducedChannels(ch, :)', 'r', 'LineWidth', 2);  % Bad channel in red
                                        %disp('Flat channel detected.');
                                    else
                                        plot(reducedChannels(ch, :)', 'k', 'LineWidth', 0.1);  % Good channel in black
                                    end
                                end
                                title(['Bad Channels Found in ', fileName]);
                                xlabel('Time Points');
                                ylabel('Amplitude');
                                legend('Bad = red', 'Location', 'northeast');
                                hold off;
                                
                            end
                            %}                         
                                                        
                            passMatrixTot = passMatrixStd & passMatrixDiff & passMatrixActive;
                            exceedIdx = find(~passMatrixTot);  % Indices of channels that failed either test
                            numBad = length(exceedIdx);
                            numGood = 63 - numBad;

                            %{

                            if length(exceedIdx) > length(exceedIdxMax)
                                disp(zScores(exceedIdxStd));
                                figure;
                                hold on;
                                for ch = 1:size(reducedChannels, 1)
                                    if ismember(ch, exceedIdxStd)
                                        plot(reducedChannels(ch, :)', 'r');  % Bad channel in red
                                    else
                                        plot(reducedChannels(ch, :)', 'k');  % Good channel in black
                                    end
                                end
                                title(['Bad Channels Found in ', fileName]);
                                xlabel('Time Points');
                                ylabel('Amplitude');
                                legend('Bad = red', 'Location', 'northeast');
                                hold off;
                            end
                            %}

                            expandedMask = repmat(passMatrixTot, 1, size(reducedChannels, 2));
                            sumMat = sumMat + reducedChannels .* expandedMask;
                            sumWeights = sumWeights + passMatrixTot;

                            subjBad = subjBad + numBad;
                            subjGood = subjGood + numGood;
                            %subjMaxList = [subjMaxList; mvChannelsDiff];                            
                            

                            %{
                            channelsMax = max(abs(reducedChannels), [], 2);
                            mvChannelsMax = channelsMax * 1e6;
                            passableMatrix = double(mvChannelsMax <= mvLimit);
                            exceedIdx = find(mvChannelsMax > mvLimit);
                            numBad = length(exceedIdx);
                            numGood = 63 - numBad;

                            expandedMask = repmat(passableMatrix, 1, size(reducedChannels, 2));
                            sumMat = sumMat + reducedChannels .* expandedMask;
                            sumWeights = sumWeights + passableMatrix;

                            subjBad = subjBad + numBad;
                            subjGood = subjGood + numGood;
                            subjMaxList = [subjMaxList; mvChannelsMax];
                            %}
                        end
                    end

                    avgMat = sumMat ./ sumWeights;
                    avgMat(isnan(avgMat)) = 0;

                    if ~all(isfinite(avgMat(:)))
                        error('Non-finite values found in channel.');
                    end

                    newStructData.(condition).(trigger).(block).epoch_avg = avgMat;
                    newStructData.(condition).(trigger).(block).num_files = sumWeights;
                end
            end
        end

        disp([num2str(modifiedCount), ' fields modified in file: ', fileName]);
        disp(['Number of good channels: ', num2str(subjGood)]);
        disp(['Number of bad channels: ', num2str(subjBad)]);
        percCorrect = (subjGood / (subjGood + subjBad)) * 100;
        disp(['Percent correct: ', num2str(round(percCorrect, 2)), '%']);

        totalGood = totalGood + subjGood;
        totalBad = totalBad + subjBad;

        wrapper = struct();
        wrapper.(outputTag) = newStructData;
        save(destinationPath, '-struct', 'wrapper', '-v7.3');
        disp(['Saved updated file to: ', destinationPath]);
        disp('');

        subjectMaxDict(nameOnly) = subjMaxList;
        subjectStats(nameOnly) = [subjGood, subjBad, percCorrect];
    end
    %{
    % Save subject_maxes.csv
    keys = subjectMaxDict.keys;
    maxLen = max(cellfun(@(k) length(subjectMaxDict(k)), keys));
    outputCSV1 = fullfile(destFolder, 'subject_maxes.csv');
    fid1 = fopen(outputCSV1, 'w');
    for i = 1:length(keys)
        if i > 1, fprintf(fid1, ','); end
        fprintf(fid1, '%s', keys{i});
    end
    fprintf(fid1, '\n');
    for r = 1:maxLen
        for i = 1:length(keys)
            thisList = subjectMaxDict(keys{i});
            if i > 1, fprintf(fid1, ','); end
            if r <= length(thisList)
                fprintf(fid1, '%.3f', thisList(r));
            end
        end
        fprintf(fid1, '\n');
    end
    fclose(fid1);
    disp(['Saved max values to CSV: ', outputCSV1]);
    %}

    % Save subject_stats.csv
    statKeys = subjectStats.keys;
    outputCSV2 = fullfile(destFolder, 'subject_stats.csv');
    fid2 = fopen(outputCSV2, 'w');
    fprintf(fid2, 'Subject,Good Channels,Bad Channels,Percent Correct\n');
    for i = 1:length(statKeys)
        key = statKeys{i};
        vals = subjectStats(key);
        fprintf(fid2, '%s,%d,%d,%.2f\n', key, vals(1), vals(2), vals(3));
    end
    fclose(fid2);
    disp(['Saved summary stats to CSV: ', outputCSV2]);

    disp('All files processed and saved to new directory.');
    disp(['Number of total good channels: ', num2str(totalGood)]);
    disp(['Number of total bad channels: ', num2str(totalBad)]);
    percCorrect = (totalGood / (totalGood + totalBad)) * 100;
    disp(['Percent correct: ', num2str(round(percCorrect, 2)), '%']);
    disp('');
end
