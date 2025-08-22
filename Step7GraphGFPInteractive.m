function Step7GraphGFPInteractive(inputDir, maxTime)

fs = 500;
tMin = -0.1;

files = dir(fullfile(inputDir, '*.mat'));
if isempty(files)
    error(['No .mat files found in ', inputDir]);
end

% Load first file to get time vector
sampleFile = load(fullfile(inputDir, files(1).name));
rootName = fieldnames(sampleFile);
condNames = fieldnames(sampleFile.(rootName{1}));
firstData = sampleFile.(rootName{1}).(condNames{1}).epoch_avg;
nSamples = size(firstData, 2);
timeVec = linspace(tMin, tMin + (nSamples-1)/fs, nSamples) * 1000;
lastIndex = find(timeVec <= maxTime * 1000, 1, 'last');
ts = timeVec(1:lastIndex);

% Low-pass filter
cutoff = 30; 
[b, a] = butter(4, cutoff / (fs / 2), 'low');

% Subject labels
subjectIDs = cell(length(files), 1);
for f = 1:length(files)
    parts = split(files(f).name, '-');
    id = parts{1};
    id = erase(id, '_6F');
    subjectIDs{f} = id;
end

% Collect GFP
allGFP = struct();
maxGFPAmp = struct();

for f = 1:length(files)
    data = load(fullfile(inputDir, files(f).name));
    rootName = fieldnames(data);
    subjStruct = data.(rootName{1});

    for c = 1:length(condNames)
        cond = condNames{c};
        if isfield(subjStruct, cond)
            epoch_avg = subjStruct.(cond).epoch_avg(:, 1:lastIndex);
            GFP = std(epoch_avg, 0, 1) * 1e6;
            GFP_filt = filtfilt(b, a, GFP);
            allGFP.(cond)(f, :) = GFP_filt;

            if ~isfield(maxGFPAmp, cond)
                maxGFPAmp.(cond) = max(GFP_filt);
            else
                maxGFPAmp.(cond) = max(maxGFPAmp.(cond), max(GFP_filt));
            end
        end
    end
end

% Plot graphs per condition
for c = 1:length(condNames)
    cond = condNames{c};

    nSubjects = size(allGFP.(cond), 1);
    totalPlots = nSubjects + 1;
    nCols = ceil(sqrt(totalPlots));
    nRows = ceil(totalPlots / nCols);

    figure('Visible', 'on', 'Position', [100 100 1400 800]);

    for f = 1:nSubjects
        subplot(nRows, nCols, f);
        hLine = plot(ts, allGFP.(cond)(f, :), 'k', 'LineWidth', 1);
        % Attach click callback to the line itself
        set(hLine, 'ButtonDownFcn', @(~, ~) openInteractiveGFPPlot(ts, allGFP.(cond)(f,:), subjectIDs{f}, cond));
        title(subjectIDs{f}, 'Interpreter', 'none', 'FontSize', 8);
        xlim([min(ts), max(ts)]);
        if f > (nRows - 1) * nCols
            xlabel('Time (ms)'); 
        end
        if mod(f - 1, nCols) == 0
            ylabel('GFP (\muV)'); 
        end
    end

    % Plot average trace
    subplot(nRows, nCols, totalPlots);
    meanGFP = mean(allGFP.(cond), 1);
    hAvg = plot(ts, meanGFP, 'k', 'LineWidth', 1.5);
    set(hAvg, 'ButtonDownFcn', @(~, ~) openInteractiveGFPPlot(ts, meanGFP, 'Average', cond));
    title('Average GFP', 'FontSize', 9, 'Interpreter', 'none');
    xlim([min(ts), max(ts)]);
    ylim([0 maxGFPAmp.(cond) * 1.1]);
    xlabel('Time (ms)'); ylabel('GFP (\muV)');
    sgtitle(['GFP per Subject - ', cond], 'Interpreter', 'none');
end

end

function openInteractiveGFPPlot(ts, trace, label, cond)
    fig = figure('Name', ['Interactive GFP - ', label, ' (', cond, ')'], ...
        'NumberTitle', 'off', 'Position', [300 300 900 400]);
    plot(ts, trace, 'k', 'LineWidth', 1.5);
    title(['Interactive GFP - ', label], 'Interpreter', 'none');
    xlabel('Time (ms)');
    ylabel('GFP (\muV)');
    xlim([min(ts), max(ts)]);
    ylim([0 max(trace) * 1.1]);

    dcm = datacursormode(fig);
    datacursormode on;
    set(dcm, 'UpdateFcn', @(~, event) {
        ['Time (ms): ', num2str(event.Position(1), '%.2f')], ...
        ['GFP (\muV): ', num2str(event.Position(2), '%.2f')]
    });

    disp(['Interactive plot opened for ', label, ' in ', cond]);
end