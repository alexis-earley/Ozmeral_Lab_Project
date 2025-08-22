function Step7GraphGFPAllSubjects(inputDir, outputDir, timeRanges, maxTime)

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

fs = 500;
tMin = -0.1;

files = dir(fullfile(inputDir, '*.mat'));
if isempty(files)
    error(['No .mat files found in ', inputDir]);
end

% Load first file to determine times
sampleFile = load(fullfile(inputDir, files(1).name));
rootName = fieldnames(sampleFile);
condNames = fieldnames(sampleFile.(rootName{1}));
firstData = sampleFile.(rootName{1}).(condNames{1}).epoch_avg;
nSamples = size(firstData, 2);
timeVec = linspace(tMin, tMin + (nSamples-1)/fs, nSamples) * 1000;

lastIndex = find(timeVec <= maxTime * 1000, 1, 'last');
ts = timeVec(1:lastIndex);

% Create LPF
cutoff = 30; 
[b, a] = butter(4, cutoff / (fs / 2), 'low');

% Extract subject IDs
subjectIDs = cell(length(files), 1);
for f = 1:length(files)
    parts = split(files(f).name, '-');
    id = parts{1};
    id = erase(id, '_6F'); % Remove tag from label
    subjectIDs{f} = id;
end

allGFP = struct(); % GFP traces
allPeaks = struct(); % Peak vals and latencies
maxGFPAmp = struct(); % Max GFP amplitude

for f = 1:length(files)
    data = load(fullfile(inputDir, files(f).name));
    rootName = fieldnames(data);
    subjStruct = data.(rootName{1});

    for c = 1:length(condNames)
        cond = condNames{c};
        if isfield(subjStruct, cond)
            epoch_avg = subjStruct.(cond).epoch_avg(:, 1:lastIndex);
            GFP = std(epoch_avg, 0, 1) * 1e6; % Convert to microvolts
            GFP_filt = filtfilt(b, a, GFP); % Apply LPF
            allGFP.(cond)(f, :) = GFP_filt;

            % Loop through each time window and store peaks
            for r = 1:size(timeRanges, 1)
                tStart = timeRanges(r, 1);
                tEnd = timeRanges(r, 2);
                idxRange = find(ts >= tStart & ts <= tEnd);
                [peakVal, peakIdx] = max(GFP_filt(idxRange));
                peakLat = ts(idxRange(1) + peakIdx - 1);
                allPeaks.(cond)(f, r).val = peakVal;
                allPeaks.(cond)(f, r).lat = peakLat;
            end

            % If this is the first time we're seeing this condition
            if ~isfield(maxGFPAmp, cond)
                maxGFPAmp.(cond) = max(GFP_filt); % Store the current subject's GFP max
            else
                % Otherwise  compare current max to stored one and keep the larger
                maxGFPAmp.(cond) = max(maxGFPAmp.(cond), max(GFP_filt));
            end
        end
    end
end

% Loop through each condition and create figures
for c = 1:length(condNames)
    cond = condNames{c};
    for peakFlag = [true, false]
        if peakFlag
            figTag = 'WithPeaks';
        else
            figTag = 'NoPeaks';
        end

        nSubjects = size(allGFP.(cond), 1);
        totalPlots = nSubjects + 1; % Include one for average
        nCols = ceil(sqrt(totalPlots));
        nRows = ceil(totalPlots / nCols);

        figure('Visible', 'off', 'Position', [100 100 1400 800]); % Hide figure while plotting

        for f = 1:nSubjects
            subplot(nRows, nCols, f);
            plot(ts, allGFP.(cond)(f, :), 'k', 'LineWidth', 1);
            hold on;

            if peakFlag
                peakColors = {'r', 'g', 'b'};
                for r = 1:size(timeRanges, 1)
                    peakLat = allPeaks.(cond)(f, r).lat;
                    peakVal = allPeaks.(cond)(f, r).val;
                    plot(peakLat, peakVal, 'x', 'Color', peakColors{r}, 'MarkerSize', 8, 'LineWidth', 1.5);
                end
            end

            title(subjectIDs{f}, 'Interpreter', 'none', 'FontSize', 8);
            %ylim([0 maxGFPAmp.(cond) * 1.1]);
            xlim([min(ts), max(ts)]);
            if f > (nRows - 1) * nCols % Checks if in bottom row
                xlabel('Time (ms)'); 
            end
            if mod(f - 1, nCols) == 0 % Checks if in first column
                ylabel('GFP (\muV)'); 
            end
        end

        % Plot average trace
        subplot(nRows, nCols, totalPlots);
        meanGFP = mean(allGFP.(cond), 1);
        plot(ts, meanGFP, 'k', 'LineWidth', 1.5);
        hold on;

        peakText = cell(1, size(timeRanges, 1));
        peakColors = {'r', 'g', 'b'};
        for r = 1:size(timeRanges, 1)
            tStart = timeRanges(r, 1);
            tEnd = timeRanges(r, 2);
            idxRange = find(ts >= tStart & ts <= tEnd);
            [peakVal, peakIdx] = max(meanGFP(idxRange));
            peakLat = ts(idxRange(1) + peakIdx - 1);
            if peakFlag
                plot(peakLat, peakVal, 'x', 'Color', peakColors{r}, 'MarkerSize', 8, 'LineWidth', 1.5);
            end
            peakText{r} = [num2str(tStart), '-', num2str(tEnd), ' ms: ', num2str(peakVal, '%.2f'), ' uV'];
        end

        title({'Average GFP', peakText{:}}, 'FontSize', 8, 'Interpreter', 'none');
        ylim([0 maxGFPAmp.(cond) * 1.1]);
        xlim([min(ts) max(ts)]);
        xlabel('Time (ms)'); ylabel('GFP (\muV)');

        sgtitle(['GFP per Subject - ', cond, ' (', figTag, ')'], 'Interpreter', 'none');
        saveas(gcf, fullfile(outputDir, ['Step7GraphGFP_', cond, '_', figTag, '.png']));
    end
end

% Save peak latency and amplitude data
save(fullfile(outputDir, 'Step7GraphGFP_Subplots_Peaks.mat'), 'allPeaks', 'timeRanges');
disp(['Saved ', num2str(length(condNames) * 2), ' figures + peak data to ', outputDir]);
end