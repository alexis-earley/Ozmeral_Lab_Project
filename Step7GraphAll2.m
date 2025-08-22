function Step7GraphAll2(sourceDir, destFolder, subplotTitle)
% Example:
%   Step7GraphAll2(sourceDir, destFolder, 'Older Hearing Impaired (Unaided)');
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

    % Define 30 Hz low-pass filter
    Fs = 500;  % Sampling rate in Hz (based on 1051 samples over ~2.1s)
    cutoff = 30;  % Low-pass cutoff
    [b, a] = butter(4, cutoff / (Fs / 2), 'low');  % 4th order filter

    for f = 1:length(files)
        filePath = fullfile(sourceDir, files(f).name);
        disp(['Processing: ', files(f).name]);

        % Load struct from file
        fileStruct = load(filePath); 
        varNames = fieldnames(fileStruct);
        weightedStruct = fileStruct.(varNames{1});

        % Setup for figure layout
        conditionList = sort(fieldnames(weightedStruct));
        numConds = length(conditionList);
        subplotCols = 2;
        subplotRows = ceil(numConds / subplotCols);
        fig = figure('Visible', 'off', 'Name', files(f).name, 'NumberTitle', 'off', ...
             'Position', [100, 100, 1400, 900]);  % Adjust size as needed

        % Loop through each condition
        for i = 1:numConds
            condition = conditionList{i};
            data = AverageData(condition, weightedStruct) * 1e6;  % Convert to µV
            [rows, cols] = size(data);
            
            % Apply low-pass filter to each channel
            for ch = 1:rows
                if all(isfinite(data(ch, :)))
                    data(ch, :) = filtfilt(b, a, data(ch, :));
                else
                    warning('Non-finite values found in channel, skipping.');
                end

                %data(ch, :) = filtfilt(b, a, data(ch, :));
            end
            %}

            GFP = std(data);  % Global Field Power

            subplot(subplotRows, subplotCols, i);
            hold on;
            ts = linspace(-0.1, 2.0, cols);  % Time vector (in seconds)
            plot(ts, data, 'b', 'LineWidth', 0.5); % Channels
            plot(ts, GFP, 'r', 'LineWidth', 2); % GFP
            xlabel('Time (s)');
            ylabel('Amplitude (µV)');
            title(condition);
            grid on;
            xlim([-0.1, 2]);
            ylim([-2, 2]);
        end

        if numConds > 1
            titleAll = [subplotTitle, ' Average Potentials - ', files(f).name];
            sgtitle(titleAll, 'Interpreter', 'none', 'FontSize', 10);

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
        for j = 1:length(triggerNames)
            dataStruct = struct.(cond).(triggerNames{j});
            if isfield(dataStruct, 'num_files')
                dataWeight = dataStruct.num_files;   % Assumes 63x1 weight
            elseif isfield(dataStruct, 'num_files_trigger')
                dataWeight = dataStruct.num_files_trigger;   % Assumes 63x1 weight
            end

            if isfield(dataStruct, 'epoch_avg')
                dataMatrix = dataStruct.epoch_avg;   % 63x1051
            elseif isfield(dataStruct, 'epoch_avg_trigger')
                dataMatrix = dataStruct.epoch_avg_trigger;   % 63x1051
            end

            if j==1
                [row, col] = size(dataMatrix);
                summedData = zeros(row, col);
                summedWeight = zeros(row, 1);
            end

            summedData = summedData + (dataMatrix .* dataWeight);
            summedWeight = summedWeight + dataWeight;
        end
        avgData = summedData ./ summedWeight;
    end
end
