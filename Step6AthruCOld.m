function Step6AthruC(sourceFolder, destFolder, mvLimit, stdLimit, flatThresh)
    if nargin < 2
        error('Source and destination folders must be specified.')
    end
    if nargin < 3
        mvLimit = 100;
    end
    if nargin < 4
        stdLimit = 6.5;
    end
    if nargin < 5
        flatThresh = 5e-8;
    end

  
    files = dir(fullfile(sourceFolder, '*.mat'));

    destFolderA = fullfile(destFolder, 'Step6A');
    if ~exist(destFolderA, 'dir'), mkdir(destFolderA); end
    destFolderB = fullfile(destFolder, 'Step6B');
    if ~exist(destFolderB, 'dir'), mkdir(destFolderB); end
    destFolderC = fullfile(destFolder, 'Step6C');
    if ~exist(destFolderC, 'dir'), mkdir(destFolderC); end

    %{
    destFolderD = fullfile(destFolder, 'Step6D');
    if ~exist(destFolderD, 'dir'), mkdir(destFolderD); end
    %}

    %{
    destFolderE = fullfile(destFolder, 'Step6E');
    if ~exist(destFolderE, 'dir'), mkdir(destFolderE); end
    destFolderF = fullfile(destFolder, 'Step6F');
    if ~exist(destFolderF, 'dir'), mkdir(destFolderF); end
    %}

    subjChannTypes = {'All passed', 'Failed peak-to-peak', 'Failed standard deviation', 'Failed active', ...
    'Failed peak-to-peak and standard deviation', 'Failed peak-to-peak and active', ...
    'Failed active and standard deviation', 'Failed all'};
    outputCSVChann = fullfile(destFolder, 'channel_failure_summary.csv');
    fChann = fopen(outputCSVChann, 'w');
    % Write header
    fprintf(fChann, 'Subject');
    for i = 1:length(subjChannTypes)
        fprintf(fChann, ',%s', subjChannTypes{i});
    end
    fprintf(fChann, '\n');

    subjRespStats = containers.Map();
    subjChanStats = containers.Map();
    totGoodChanns = 0;
    totBadChanns = 0;
    
    %{
    outputTagE = 'All_Subjects_6E';
    destinationPathE = fullfile(destFolderE, [outputTagE '.mat']);
    
    outputTagF = 'All_Subjects_6F';
    destinationPathF = fullfile(destFolderF, [outputTagF '.mat']);

    newStructDataE = struct();
    newStructDataF = struct();
    %}

    for j = 1:length(files)
        fileName = files(j).name;
        sourcePath = fullfile(sourceFolder, fileName);

        disp(['Processing file: ', fileName]);
        data = load(sourcePath);
        varName = fieldnames(data);
        topVarName = varName{1};
        structData = data.(topVarName);
        disp(['Loaded struct variable: ', topVarName]);
        fprintf('\n');

        [~, nameOnly, ~] = fileparts(fileName);
        outputTagA = [nameOnly '_6A'];
        destinationPathA = fullfile(destFolderA, [outputTagA '.mat']);
        outputTagB = [nameOnly '_6B'];
        destinationPathB = fullfile(destFolderB, [outputTagB '.mat']);
        outputTagC = [nameOnly '_6C'];
        destinationPathC = fullfile(destFolderC, [outputTagC '.mat']);
        %{
        outputTagD = [nameOnly '_6D'];
        destinationPathD = fullfile(destFolderD, [outputTagD '.mat']);
        %}

        tempStruct = struct(); % Clear for each new files
        newStructDataA = struct();
        newStructDataB = struct();
        newStructDataC = struct();
        %{
        newStructDataD = struct();
        %}

        subjGoodChanns = 0;
        subjBadChanns = 0;
        subjChannCounts = zeros(1,length(subjChannTypes));
        subjGoodAns = 0;
        subjBadAns = 0;

        condNames = fieldnames(structData);
        %{
        condTotData = zeros(63,1051);
        condTotChannels = zeros(63,1);
        %}

        for i = 1:length(condNames)
            condition = condNames{i};
            triggerNames = fieldnames(structData.(condition));
            
            %{
            % TRY 2
            if ~isfield(newStructDataE, condition)
                newStructDataE.(condition) = struct();
            end
            if ~isfield(newStructDataF, condition)
                newStructDataF.(condition) = struct();
                structFData = zeros(63,1051);
                structFChannels = zeros(63,1);
            end
            %}

            %{
            trigTotData = zeros(63,1051);
            trigTotChannels = zeros(63,1);
            %}

            for j2 = 1:length(triggerNames)
                trigger = triggerNames{j2};
                blockNames = fieldnames(structData.(condition).(trigger));

                %{ 
                % TRY 2
                if ~isfield(newStructDataE, trigger)
                    newStructDataE.(condition).(trigger) = struct();
                    structEData = zeros(63,1051);
                    structEChannels = zeros(63,1);
                end
                %}

                goodTrig = includeTrigger(condition, trigger);

                blockTotData = zeros(63,1051);
                blockTotChannels = zeros(63,1);

                for k = 1:length(blockNames)
                    block = blockNames{k};

                    epochNames = fieldnames(structData.(condition).(trigger).(block));

                    epTotData = zeros(63,1051);
                    epTotChannels = zeros(63,1);

                    for m = 1:length(epochNames)                      

                        epoch = epochNames{m};
                        matrix = structData.(condition).(trigger).(block).(epoch);

                        if ~(isnumeric(matrix) && ismatrix(matrix))
                            error('Matrix is not numeric or is not a 2D matrix.');
                        end

                        if goodTrig
                            subjGoodAns = subjGoodAns + 1;
                        else
                            subjBadAns = subjBadAns + 1;
                            continue; % VERY IMPORTANT
                        end

                        nRows = size(matrix, 1);
                        if nRows == 63
                            reducedChannels = matrix;
                        elseif nRows == 70 || nRows == 88
                            rowsToDelete = [32, 65:nRows];
                            reducedChannels = matrix(setdiff(1:nRows, rowsToDelete), :);
                        elseif nRows == 69
                            rowsToDelete = 64:nRows;
                            reducedChannels = matrix(setdiff(1:nRows, rowsToDelete), :);
                        else
                            error(['Matrix "', epoch, '" has ', num2str(nRows), ...
                                   ' rows (expected 63, 69, 70, or 88).']);
                        end
                        
                        % Omit channels if peak-to-peak difference is too large 
                        channelsMax = max((reducedChannels), [], 2);
                        channelsMin = min((reducedChannels), [], 2);
                        channelsDiff = channelsMax - channelsMin;
                        mvChannelsDiff = channelsDiff * 1e6;
                        passMatrixDiff = double(mvChannelsDiff <= mvLimit);
  
                        % Omit channels if standard deviation is too high
                        channelStd = std(reducedChannels, 0, 2);  % Std deviation across time for each channel
                        meanStd = mean(channelStd, 'omitnan');
                        stdOfStd = std(channelStd, 'omitnan');       
                        zScores = abs(channelStd - meanStd) / stdOfStd;
                        passMatrixStd = double(zScores <= stdLimit);  % stdLimit typically 3
                        
                        % Omit channels if too flat
                        passMatrixActive = double(channelStd >= flatThresh);  % 1 = not flat, 0 = flat}       

                        % Count how many channels passed or failed each combination of criteria
                        allPass = passMatrixDiff & passMatrixStd & passMatrixActive;
                        failPeak = ~passMatrixDiff & passMatrixStd & passMatrixActive;
                        failStd = passMatrixDiff & ~passMatrixStd & passMatrixActive;
                        failActive = passMatrixDiff & passMatrixStd & ~passMatrixActive;
                        failPeakStd = ~passMatrixDiff & ~passMatrixStd & passMatrixActive;
                        failPeakActive = ~passMatrixDiff & passMatrixStd & ~passMatrixActive;
                        failStdActive = passMatrixDiff & ~passMatrixStd & ~passMatrixActive;
                        allFail = ~passMatrixDiff & ~passMatrixStd & ~passMatrixActive;
                        
                        tempChannCounts = zeros(1, length(subjChannCounts));
                        numGood = sum(allPass); tempChannCounts(1) = tempChannCounts(1) + numGood;
                        countFailPeak = sum(failPeak); tempChannCounts(2) = tempChannCounts(2) + countFailPeak;
                        countFailStd = sum(failStd); tempChannCounts(3) = tempChannCounts(3) + countFailStd;
                        countFailActive = sum(failActive); tempChannCounts(4) = tempChannCounts(4) + countFailActive;
                        countFailPeakStd = sum(failPeakStd); tempChannCounts(5) = tempChannCounts(5) + countFailPeakStd;
                        countFailPeakActive = sum(failPeakActive); tempChannCounts(6) = tempChannCounts(6) + countFailPeakActive;
                        countFailStdActive = sum(failStdActive); tempChannCounts(7) = tempChannCounts(7) + countFailStdActive;
                        countAllFail = sum(allFail); tempChannCounts(8) = tempChannCounts(8) + countAllFail;

                        subjChannCounts = subjChannCounts + tempChannCounts;
                        if sum(tempChannCounts) ~= 63
                            error('Counting bad channels has not worked.')
                        end
                        
                        numBad = 63 - numGood;
                        subjBadChanns = subjBadChanns + numBad;
                        subjGoodChanns = subjGoodChanns + numGood;

                        goodData = reducedChannels .* allPass;

                        newStructDataA.(condition).(trigger).(block).(epoch).epoch_avg = goodData;
                        newStructDataA.(condition).(trigger).(block).(epoch).num_files = allPass;

                        epTotData = epTotData + goodData;
                        epTotChannels = epTotChannels + allPass;

                        blockTotData = blockTotData + goodData;
                        blockTotChannels = blockTotChannels + allPass;

                        %{

                        trigTotData = trigTotData + goodData;
                        trigTotChannels = trigTotChannels + goodChannels;

                        condTotData = condTotData + goodData;
                        condTotChannels = condTotChannels + goodChannels;

                        structEData = structEData + goodData;
                        structEChannels = structEData + goodData;

                        structFData = structFData + goodData;
                        structFChannels = structFData + goodData;
                        %}
                       
                    end

                    if goodTrig

                        epAvgData = epTotData ./ epTotChannels;
                        %epAvgData(isnan(epAvgData)) = 0;
                        epAvgData(epTotChannels == 0, :) = 0;
    
                        newStructDataB.(condition).(trigger).(block).epoch_avg = epAvgData;
                        newStructDataB.(condition).(trigger).(block).num_files = epTotChannels;
                    end

                end

                if goodTrig
                
                    blockAvgData = blockTotData ./ blockTotChannels;
                    %blockAvgData(isnan(blockAvgData)) = 0;
                    blockAvgData(blockTotChannels == 0, :) = 0;
    
                    newStructDataC.(condition).(trigger).epoch_avg = blockAvgData;
                    newStructDataC.(condition).(trigger).num_files = blockTotChannels;

                    %{
                    % TRY 1
                    % Compute weighted average for trigger within subject
                    weightedData = blockAvgData .* blockTotChannels;
                    totalWeight = blockTotChannels;
                    avgData = weightedData ./ totalWeight;
                    avgData(isnan(avgData)) = 0;  % Set any NaNs from divide-by-zero to 0
                    
                    % Initialize struct fields if not already present
                    if ~isfield(newStructDataE, condition)
                        newStructDataE.(condition) = struct();
                    end
                    if ~isfield(newStructDataE.(condition), trigger)
                        newStructDataE.(condition).(trigger) = struct();
                    end
                    
                    % Store averaged data and total weights
                    newStructDataE.(condition).(trigger).epoch_avg = avgData;
                    newStructDataE.(condition).(trigger).num_files = totalWeight;
                    %}

                end
            end

            %{
            trigAvgData = trigTotData ./ trigTotChannels;
            matrix(isnan(trigAvgData)) = 0;

            newStructDataD.(condition).epoch_avg = trigAvgData;
            newStructDataD.(condition).num_files = trigTotChannels;
            %}

            %{
            % TRY 2
            % Compute weighted average across triggers within this condition
            weightedData = trigAvgData .* trigTotChannels;
            totalWeight = trigTotChannels;
            avgData = weightedData ./ totalWeight;
            avgData(isnan(avgData)) = 0;  % Replace any NaNs with 0
            
            % Initialize if not already present
            if ~isfield(newStructDataF, condition)
                newStructDataF.(condition) = struct();
            end
            
            
            % Store averaged data and weight
            newStructDataF.(condition).epoch_avg = avgData;
            newStructDataF.(condition).num_files = totalWeight;
            %}
        end

        if subjGoodChanns ~= subjChannCounts(1)
            error('subjGoodChanns is not equal to subjChannCounts(1)');
        end

        fprintf(fChann, '%s', nameOnly);
        for i = 1:length(subjChannCounts)
            subjChannType = subjChannTypes{i}; 
            subjChannCount = subjChannCounts(i);
            disp([subjChannType, ' : ', num2str(subjChannCount)]);
            fprintf(fChann, ',%d', subjChannCounts(i));
        end
        fprintf(fChann, '\n');

        disp(['Number of correct responses: ', num2str(subjGoodAns)]);
        disp(['Number of incorrect responses: ', num2str(subjBadAns)]);
        respPerc = (subjGoodAns / (subjGoodAns + subjBadAns)) * 100;
        disp(['Percent correct: ', num2str(round(respPerc,2)), '%']);
        fprintf('\n');

        disp(['Number of good channels: ', num2str(subjGoodChanns)]);
        disp(['Number of bad channels: ', num2str(subjBadChanns)]);
        chanPerc = (subjGoodChanns / (subjGoodChanns + subjBadChanns)) * 100;
        disp(['Percent correct: ', num2str(round(chanPerc,2)), '%']);
        fprintf('\n');

        % Save subject data to maps
        subjRespStats(nameOnly) = [subjGoodAns, subjBadAns, respPerc];
        subjChanStats(nameOnly) = [subjGoodChanns, subjBadChanns, chanPerc];

        totGoodChanns = totGoodChanns + subjGoodChanns;
        totBadChanns = totBadChanns + subjBadChanns;

        % Save updated struct A - cleaned data
        tempStruct.(outputTagA) = newStructDataA;
        save(destinationPathA, '-struct', 'tempStruct', '-v7.3');
        disp(['Saved updated file to: ', destinationPathA]);
        
        % Save updated struct B - block average
        tempStruct = struct();  % Reset struct
        tempStruct.(outputTagB) = newStructDataB;
        save(destinationPathB, '-struct', 'tempStruct', '-v7.3');
        disp(['Saved updated file to: ', destinationPathB]);

        % Save updated struct C - trigger average
        tempStruct = struct();  % Reset struct
        tempStruct.(outputTagC) = newStructDataC;
        save(destinationPathC, '-struct', 'tempStruct', '-v7.3');
        disp(['Saved updated file to: ', destinationPathC]);

        %{

        % Save updated struct D - condition average
        tempStruct = struct();  % Reset struct
        tempStruct.(outputTagD) = newStructDataD;
        save(destinationPathD, '-struct', 'tempStruct', '-v7.3');
        disp(['Saved updated file to: ', destinationPathD]);
        fprintf('\n');
        %}
    end

    %{
    % Save updated struct E - subject average
    tempStruct = struct();  % Reset struct
    tempStruct.(outputTagE) = newStructDataE;
    save(destinationPathE, '-struct', 'tempStruct', '-v7.3');
    disp(['Saved updated file to: ', destinationPathE]);

    % Save updated struct F - total average
    tempStruct = struct();  % Reset struct
    tempStruct.(outputTagF) = newStructDataF;
    save(destinationPathF, '-struct', 'tempStruct', '-v7.3');
    disp(['Saved updated file to: ', destinationPathF]);
    fprintf('\n');
    %}
    
    % Summary
    disp('All subject files processed and saved to new directory.');
    disp(['Number of total good channels: ', num2str(totGoodChanns)]);
    disp(['Number of total bad channels: ', num2str(totBadChanns)]);
    chanPerc = (totGoodChanns / (totGoodChanns + totBadChanns)) * 100;
    disp(['Percent correct: ', num2str(round(chanPerc,2)), '%']);
    subjChanStats('Total') = [subjGoodChanns, subjBadChanns, chanPerc];
    fprintf('\n');
    
    % Close channels description
    fclose(fChann);

    % Save subject_response_stats.csv
    responseKeys = subjRespStats.keys;
    outputCSV1 = fullfile(destFolder, 'subject_response_stats.csv');
    csvfile1 = fopen(outputCSV1, 'w');
    fprintf(csvfile1, 'Subject, Correct Responses, Incorrect Responses, Percent Correct\n');
    for i = 1:length(responseKeys)
        key = responseKeys{i};
        vals = subjChanStats(key);
        fprintf(csvfile1, '%s,%d,%d,%.2f\n', key, vals(1), vals(2), vals(3));
    end
    fclose(csvfile1);
    disp(['Saved summary stats to CSV: ', outputCSV1]);   

    % Save subject_channel_stats.csv
    channelKeys = subjChanStats.keys;
    outputCSV2 = fullfile(destFolder, 'subject_channel_stats.csv');
    csvfile2 = fopen(outputCSV2, 'w');
    fprintf(csvfile2, 'Subject, Good Channels, Bad Channels, Percent Correct\n');
    for i = 1:length(channelKeys)
        key = channelKeys{i};
        vals = subjChanStats(key);
        fprintf(csvfile2, '%s,%d,%d,%.2f\n', key, vals(1), vals(2), vals(3));
    end
    fclose(csvfile2);
    disp(['Saved summary stats to CSV: ', outputCSV2]);   

    % Save limit_stats.csv
    outputTXT = fullfile(destFolder, 'limit_stats.txt');
    txtfile = fopen(outputTXT, 'w');
    fprintf(txtfile, ['Peak to peak maximum limit: ', num2str(mvLimit), 'µV.\n']);
    fprintf(txtfile, ['Peak to peak minimum limit: ', num2str(flatThresh), 'µV.\n']);
    fprintf(txtfile, ['Standard devation limit: ', num2str(stdLimit), '.\n']);
    fclose(txtfile);
    disp(['Saved summary stats to CSV: ', outputTXT]);
    disp('');
    
end


function includeBool = includeTrigger(condition, trigger)

% See if this is an active condition
isActiveCond = strncmp(condition, 'Attend', 6);

% If Passive:
if ~isActiveCond
    includeBool = true;
    return;
end

% If Active:
%           To 60L: To 30L: To 0:   To 30R: To 60R:         
% From 60L: 1       2       3       4       5
% From 30L: 6       7       8       9       10
% From 0:   11      12      13      14      15
% From 30R: 16      17      18      19      20
% From 60R: 21      22      23      24      25

locMatrix = reshape(1:25, [5, 5])'; 
locLabels = {'60L', '30L', '0', '30R', '60R'}; % Column titles

attendLabel = condition(7:end);
trigParts = split(trigger, '_');
triggerNum = trigParts{2};
triggerTag = trigParts{3};

% Find the column number of this trigger in the location matrix
[~, locIdx] = find(locMatrix == str2double(triggerNum)); % Ex. 5 for trigger 25
soundLoc = locLabels{locIdx}; % Ex. sound was at location 30R

if soundLoc == attendLabel
    if triggerTag == 'Y'; includeBool = true; return;
    elseif triggerTag == 'N'; includeBool = false; return;
    end
else
    if triggerTag == 'Y'; includeBool = false; return;
    elseif triggerTag == 'N'; includeBool = true; return;
    end
end

end
