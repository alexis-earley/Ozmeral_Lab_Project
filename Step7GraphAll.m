function Step7GraphAll(sourceDir, destFolder, subplotTitle)
% Example:
%   Step7GraphAll(sourceDir, destFolder, 'Older Hearing Impaired (Unaided)');
% Input should be from Step6DNew

    % Ensure output directory exists
    if ~exist(destFolder, 'dir')
        mkdir(destFolder);
    end

    % Get all .mat files from source directory
    files = dir(fullfile(sourceDir, '*.mat'));
    if isempty(files)
        error('No .mat files found in source directory.');
    end

    for f = 1:length(files)
        filePath = fullfile(sourceDir, files(f).name);
        disp(['Processing: ', files(f).name]);

        % Load struct from file
        fileStruct = load(filePath); 
        varNames = fieldnames(fileStruct);
        weightedStruct = fileStruct.(varNames{1});

        numSamples = 1051;
        ts = linspace(-0.1, 2.0, numSamples);  % Time vector (in seconds)

        % Setup for figure layout
        conditionList = sort(fieldnames(weightedStruct));
        numConds = length(conditionList);
        subplotCols = 2;
        subplotRows = ceil(numConds / subplotCols);
        fig = figure('Visible', 'off', 'Name', files(f).name, 'NumberTitle', 'off');

        % Loop through each condition
        for i = 1:numConds
            condition = conditionList{i};
            data = AverageData(condition, weightedStruct) * 1e6;
            GFP = std(data);  % Global Field Power

            subplot(subplotRows, subplotCols, i);
            hold on;
            plot(ts, data, 'b', 'LineWidth', 0.1);  % Channels
            plot(ts, GFP, 'r', 'LineWidth', 2);     % GFP
            xlabel('Time (s)');
            ylabel('Amplitude (µV)');
            title(condition);
            grid on;
            xlim([0, 0.75]);
        end

        if numConds > 1
            sgtitle([subplotTitle, ' Average Potentials - ', strrep(files(f).name, '_', '\_')]);
        end

        % Save figure using base name from input file, appending index if needed
        [~, baseName, ~] = fileparts(files(f).name);
        saveBase = fullfile(destFolder, [baseName, '_AllConditions.png']);
        savePath = saveBase;
        suffix = 1;
        while isfile(savePath)
            savePath = fullfile(destFolder, [baseName, '_AllConditions_', num2str(suffix), '.png']);
            suffix = suffix + 1;
        end

        exportgraphics(fig, savePath);
        close(fig);
        disp(['Saved figure to: ', savePath]);
    end

    disp('All figures processed.');

    % Helper function to compute weighted average across all triggers
    function avgData = AverageData(cond, struct)
        triggerNames = fieldnames(struct.(cond));
        summedData = zeros(63, 1051);
        summedWeight = 0;
        for j = 1:length(triggerNames)
            dataStruct = struct.(cond).(triggerNames{j});
            
            if isfield(dataStruct, 'num_files')
                dataWeight = dataStruct.num_files;
            elseif isfield(dataStruct, 'num_files_trigger')
                dataWeight = dataStruct.num_files_trigger;
            end

            if isfield(dataStruct, 'epoch_avg')
                dataMatrix = dataStruct.epoch_avg;
            elseif isfield(dataStruct, 'epoch_avg_trigger')
                dataMatrix = dataStruct.epoch_avg_trigger;
            end 
            summedData = summedData + dataMatrix * dataWeight;
            summedWeight = summedWeight + dataWeight;
        end
        avgData = summedData / summedWeight;
    end
end