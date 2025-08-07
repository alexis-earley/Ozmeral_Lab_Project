function Step7GraphBlocks(inputDir, outputDir, subplotTitle)
% Generates one figure per subject with subplots for each condition/block combo.
% Applies a 30 Hz low-pass filter to EEG signals before plotting.

    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    files = dir(fullfile(inputDir, '*.mat'));
    if isempty(files)
        error('No .mat files found in input directory.');
    end

    % Define low-pass filter
    Fs = 500;        % Sampling frequency in Hz
    cutoff = 30;     % Cutoff frequency in Hz
    [b, a] = butter(4, cutoff / (Fs / 2), 'low');  % 4th-order Butterworth LPF

    for i = 1:length(files)
        filePath = fullfile(inputDir, files(i).name);
        disp(['Processing: ', files(i).name]);

        fileStruct = load(filePath);
        varNames = fieldnames(fileStruct);
        weightedStruct = fileStruct.(varNames{1});

        condList = fieldnames(weightedStruct);
        numConds = length(condList);
        numSamples = 1051;
        ts = linspace(-0.1, 2.0, numSamples);

        subplotCols = 6;
        subplotRows = ceil(numConds / subplotCols);

        fig = figure('Visible', 'off', 'Units', 'pixels', 'Position', [100, 100, 2400, 1400]);
        t = tiledlayout(subplotRows, subplotCols, 'TileSpacing', 'compact', 'Padding', 'compact');

        for j = 1:numConds
            condition = condList{j};
            dataStruct = weightedStruct.(condition);
            data = dataStruct.epoch_avg * 1e6;  % Convert to µV

            % Apply 30 Hz low-pass filter to each channel
            for ch = 1:size(data, 1)
                data(ch, :) = filtfilt(b, a, data(ch, :));
            end

            GFP = std(data);

            nexttile;
            hold on;
            plot(ts, data, 'b', 'LineWidth', 0.1);
            plot(ts, GFP, 'r', 'LineWidth', 2);
            xlabel('Time (s)', 'FontSize', 8);
            ylabel('Amplitude (µV)', 'FontSize', 8);
            title(strrep(condition, '_', '\_'), 'FontSize', 9);
            xlim([0, 0.75]);
            ylim([-15, 15]);
            grid on;
        end

        sgtitle([subplotTitle, ' - ', strrep(files(i).name, '_', '\_')], 'FontSize', 12);

        saveName = [files(i).name(1:end-4), '_EEGPlot.png'];
        savePath = fullfile(outputDir, saveName);
        exportgraphics(fig, savePath, 'Resolution', 300);
        close(fig);
    end
end
