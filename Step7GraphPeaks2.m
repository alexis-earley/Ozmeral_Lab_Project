function Step7GraphPeaks2(inputDir, outputDir, timeRanges, step7GTitle)
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

    % Loop subjects and compute per-condition peaks
    for f = 1:length(files)
        disp(['Processing subject ', num2str(f), '/', num2str(length(files))]);

        filePath = fullfile(inputDir, files(f).name);
        data = load(filePath);
        rootName = fieldnames(data); 
        subjStruct = data.(rootName{1});

        cNames = fieldnames(subjStruct); % all conditions present in this subject
        for c = 1:length(cNames)
            condName = cNames{c};
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

    % Build a master condition list across ALL subjects (robust to missing conditions)
    tmpCond = {};
    for s = 1:length(allResults)
        tmpCond = [tmpCond; fieldnames(allResults(s))]; %#ok<AGROW>
    end
    condList = unique(tmpCond);

    % 3 boxplots for peak amplitude, 3 for latency
    figure('Visible','off', 'Position', [100 100 1400 800]);

    for timeWindow = 1:3

        % ----- Amplitude boxplots -----
        subplot(2, 3, timeWindow); 
        hold on;
        voltageVals = []; % All voltage values
        voltCondLabels = []; % All condition labels

        % Collect amplitude values per condition
        for c = 1:length(condList)
            ampVals = nan(1, length(allResults)); % Preallocate with NaN (missing subjects stay NaN)
        
            % Loop through each subject
            for i = 1:length(allResults)
                if isfield(allResults(i), condList{c}) && ...
                        numel(allResults(i).(condList{c}).range) >= timeWindow && ...
                        isfield(allResults(i).(condList{c}).range(timeWindow), 'peakVal')
                    ampVals(i) = allResults(i).(condList{c}).range(timeWindow).peakVal;
                end
            end
        
            voltageVals = [voltageVals; ampVals(:)]; %#ok<AGROW>
            voltCondLabels = [voltCondLabels; repmat({condList{c}}, numel(ampVals), 1)]; %#ok<AGROW>
        end

        % Create boxplot for amplitudes (boxplot ignores NaNs)
        boxplot(voltageVals, voltCondLabels);
        title(['Peak Amp ', num2str(timeRanges(timeWindow,1)), '–', num2str(timeRanges(timeWindow,2)), ' ms']);
        ylabel('Amplitude (\muV)');
        set(gca, 'XTickLabelRotation', 30); % Make sure these don't overlap
        %ylim([0 max(voltageVals, [], 'omitnan')*1.1]); % Optional: set y-limit slightly above max (ignoring NaNs)

        % ----- Latency boxplots -----
        subplot(2, 3, timeWindow+3); 
        hold on;
        latencyVals = []; 
        latCondLabels = [];

        % Collect latency values per condition
        for c = 1:numel(condList)
            currLatencies = nan(length(allResults), 1); % NaN default
        
            for s = 1:length(allResults)
                if isfield(allResults(s), condList{c}) && ...
                        numel(allResults(s).(condList{c}).range) >= timeWindow && ...
                        isfield(allResults(s).(condList{c}).range(timeWindow), 'peakLat')
                    currLatencies(s) = allResults(s).(condList{c}).range(timeWindow).peakLat;
                end
            end
        
            latencyVals = [latencyVals; currLatencies(:)]; %#ok<AGROW>
            latCondLabels = [latCondLabels; repmat({condList{c}}, numel(currLatencies), 1)]; %#ok<AGROW>
        end

        % Create boxplot for latencies (boxplot ignores NaNs)
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
