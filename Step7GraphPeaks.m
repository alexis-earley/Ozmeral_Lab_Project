function Step7GraphPeaks(inputDir, outputDir, timeRanges)
    % Graphs boxplots and saves variables

    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    files = dir(fullfile(inputDir, '*.mat'));
    if isempty(files)
        error(['No .mat files found in ', inputDir]);
    end

    fs = 500; 
    tMin = -0.1;

    % Load first file to determine times
    sampleFile = load(fullfile(inputDir, files(1).name));
    rootName = fieldnames(sampleFile);
    condNames = fieldnames(sampleFile.(rootName{1}));
    firstData = sampleFile.(rootName{1}).(condNames{1}).epoch_avg; % First EEG data
    nSamples = size(firstData, 2); % Number of time points
    timeVec = linspace(tMin, tMin + (nSamples-1)/fs, nSamples) * 1000; % Times in ms

    % Initialize struct for subjects' peak values and latencies
    allResults = struct();

    for f = 1:length(files)
        disp(['Processing subject ', num2str(f), '/', num2str(length(files))]);

        filePath = fullfile(inputDir, files(f).name);
        data = load(filePath);
        rootName = fieldnames(data); 
        subjStruct = data.(rootName{1});

        condNames = fieldnames(subjStruct);
        for c = 1:length(condNames)
            condName = condNames{c};
            epoch_avg = subjStruct.(condName).epoch_avg;

            GFP = std(epoch_avg, 0, 1) * 1e6; % Compute GFP in microvolts

            for timeWindow = 1:size(timeRanges, 1) % Loop through (presumably 3) time windows
                tStart = timeRanges(timeWindow,1);
                tEnd   = timeRanges(timeWindow,2); 

                idxRange = find(timeVec >= tStart & timeVec <= tEnd); % Indices of time vectors

                [peakVal, peakIdx] = max(GFP(idxRange)); % peakVal = max voltage, peakIdx = index where it occurs
                peakLat = timeVec(idxRange(1) + peakIdx - 1); % Find latency based on index

                % Save in struct
                allResults(f).(condName).range(timeWindow).peakVal = peakVal;
                allResults(f).(condName).range(timeWindow).peakLat = peakLat;
            end
        end
    end

    % 3 boxplots for peak amplitude, 3 for latency
    figure('Visible','off', 'Position', [100 100 1400 800]);
    condList = fieldnames(allResults(1)); % List of all conditions 

    for timeWindow = 1:3

        subplot(2, 3, timeWindow); 
        hold on;
        voltageVals = []; % All voltage values
        voltCondLabels = []; % All condition labels

        % Collect amplitude values per condition
        for c = 1:length(condList)
            ampVals = zeros(1, length(allResults)); % Preallocate array for this condition
        
            % Loop through each subject
            for i = 1:length(allResults) % Struct from earlier
                ampVals(i) = allResults(i).(condList{c}).range(timeWindow).peakVal;
            end
        
            voltageVals = [voltageVals; ampVals(:)]; % Add to list of all conditions
            voltCondLabels = [voltCondLabels; repmat({condList{c}}, numel(ampVals), 1)]; % Add to list of all labels
        end

        % Create boxplot for amplitudes
        boxplot(voltageVals, voltCondLabels);
        title(['Peak Amp ', num2str(timeRanges(timeWindow,1)), '–', num2str(timeRanges(timeWindow,2)), ' ms']);
        ylabel('Amplitude (\muV)');
        set(gca, 'XTickLabelRotation', 30); % Make sure these don't overlap
        %ylim([0 max(voltageVals)*1.1]); % Set y-limit slightly above max

        
        subplot(2, 3, timeWindow+3); hold on;
        latencyVals = []; 
        latCondLabels = [];

        % Do same thing w/ latency
        for c = 1:numel(condList)
            currLatencies = zeros(length(allResults), 1);
            for s = 1:length(allResults)
                currLatencies(s) = allResults(s).(condList{c}).range(timeWindow).peakLat;
            end
        
            latencyVals = [latencyVals; currLatencies(:)]; % Add values
            latCondLabels = [latCondLabels; repmat({condList{c}}, numel(currLatencies), 1)]; % Add condition names
        end

        % Create boxplot for latencies
        boxplot(latencyVals, latCondLabels);
        title(['Peak Latency ', num2str(timeRanges(timeWindow,1)), '–', num2str(timeRanges(timeWindow,2)), ' ms']);
        ylabel('Latency (ms)');
        set(gca, 'XTickLabelRotation', 30);
    end

    sgtitle(step7GTitle, 'FontSize', 16, 'FontWeight', 'bold');

    save(fullfile(outputDir, 'Step7GraphPeaks_Results.mat'), 'allResults', 'timeRanges');
    saveas(gcf, fullfile(outputDir, 'Step7GraphPeaks.png'));
    disp(['Results saved in ', outputDir]);
end