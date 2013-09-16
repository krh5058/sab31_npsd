classdef main < handle
    % main.m class for npsd.m
    % See dated ReadMe file
    
    properties
        debug = 0; % Debug on/off
        monitor
        path
        exp
        image
        temp_t
        abort = 0;
    end
    
    properties (SetObservable)
       dat
    end
    
    events
       fix
       showimg
       txt
    end
    
    methods (Static)
        function [monitor] = disp()
            % Find out screen number.
            debug = 0;
            if debug
                %                 whichScreen = max(Screen('Screens'));
                whichScreen = 1;
                Screen('Preference', 'Verbosity', 5);
            else
                whichScreen = 0;
            end
            oldVisualDebugLevel = Screen('Preference', 'VisualDebugLevel',0);
%             oldOverrideMultimediaEngine = Screen('Preference', 'OverrideMultimediaEngine', 1);
%             Screen('Preference', 'ConserveVRAM',4096);
%             Screen('Preference', 'VBLTimestampingMode', 1);
            
            % Opens a graphics window on the main monitor (screen 0).  If you have
            % multiple monitors connected to your computer, then you can specify
            % a different monitor by supplying a different number in the second
            % argument to OpenWindow, e.g. Screen('OpenWindow', 2).
            [window,rect] = Screen('OpenWindow', whichScreen);
            
            % Screen center calculations
            center_W = rect(3)/2;
            center_H = rect(4)/2;
            
            % ---------- Color Setup ----------
            % Gets color values.
            
            % Retrieves color codes for black and white and gray.
            black = BlackIndex(window);  % Retrieves the CLUT color code for black.
            white = WhiteIndex(window);  % Retrieves the CLUT color code for white.
            
            gray = (black + white) / 2;  % Computes the CLUT color code for gray.
            if round(gray)==white
                gray=black;
            end
            
            gray2 = gray*1.5;  % Lighter gray
            
            % Taking the absolute value of the difference between white and gray will
            % help keep the grating consistent regardless of whether the CLUT color
            % code for white is less or greater than the CLUT color code for black.
            absoluteDifferenceBetweenWhiteAndGray = abs(white - gray);
            
            % Data structure for monitor info
            monitor.whichScreen = whichScreen;
            monitor.rect = rect;
            monitor.center_W = center_W;
            monitor.center_H = center_H;
            monitor.black = black;
            monitor.white = white;
            monitor.gray = gray;
            monitor.gray2 = gray2;
            monitor.absoluteDifferenceBetweenWhiteAndGray = absoluteDifferenceBetweenWhiteAndGray;
            monitor.oldVisualDebugLevel = oldVisualDebugLevel;
%             monitor.oldOverrideMultimediaEngine = oldOverrideMultimediaEngine;
            
            Screen('CloseAll');
        end
    end
    
    methods
        function obj = main(varargin)
            ext = [];
            d = [];
            
            % Argument evaluation
            for i = 1:nargin
               if ischar(varargin{i}) % Assume main directory path string
                   ext = varargin{i};
               elseif iscell(varargin{i}) % Assume associated directories
                   d = varargin{i};
               else
                   fprintf(['main.m (main): Other handles required for argument value: ' int2str(i) '\n']);
               end
            end
            
            % Path property set-up
            if isempty(ext) || isempty(d)
                error('main.m (main): Empty path string or subdirectory list.');
            else
                try
                    fprintf('main.m (main): Executing path directory construction...\n');
                    obj.pathset(d,ext);
                    fprintf('main.m (main): obj.pathset() success!\n');
                catch ME
                    throw(ME);
                end
            end
            
            % Display properties set-up
            try
                fprintf('main.m (main): Gathering screen display details (Static)...\n');
                monitor = obj.disp; % Static method
                fprintf('main.m (disp): Storing monitor property.\n');
                obj.monitor = monitor;
                fprintf('main.m (main): obj.disp success!\n');
            catch ME
                throw(ME);
            end
            
            % Experimental properties set-up
            try
                fprintf('main.m (main): Gathering experimental details...\n');
                obj.expset();
                fprintf('main.m (main): obj.expset() success!\n');
            catch ME
                throw(ME);
            end
            
            % Load images
            try
                fprintf('main.m (main): Loading images...\n');
                obj.imgload();
                fprintf('main.m (main): obj.imgload() success!\n');
            catch ME
                throw(ME);
            end            
            
        end
        
        function [path] = pathset(obj,d,ext)
            if all(cellfun(@(y)(ischar(y)),d))
                for i = 1:length(d)
                    path.(d{i}) = [ext filesep d{i}];
                    [~,d2] = system(['dir /ad-h/b ' ext filesep d{i}]);
                    if ~isempty(d2)
                        d2 = regexp(strtrim(d2),'\n','split');
                        for j = 1:length(d2)
                            path.(d2{j}) = [ext filesep d{i} filesep d2{j}];
                        end
                    end
                end
                fprintf('main.m (pathset): Storing path property.\n');
                obj.path = path;
            else
                error('main.m (pathset): Check subdirectory argument.')
            end
        end
        
        function [exp] = expset(obj)
            
            % Try to list xls directory
            try
                [~,d] = system(['dir /b/a-h ' obj.path.xls]);
                d = regexp(strtrim(d),'\n','split');
                runvals = d;
            catch ME
                throw(ME);
            end
            
            dat = cell([2 3]);
            for i = 1:length(d)
                fprintf('main.m (expset): Reading presentation information -- %s.\n', d{i});
                [n,t] = xlsread([obj.path.xls filesep d{i}]);
                t(2:end,1:3) = num2cell(n);
                
                % Pulling header information
                head = t(1,:);
                onset = cellfun(@(y2)(~isempty(y2)),cellfun(@(y)(regexp(y,'[Ss]tart\W?[Tt]ime')),head,'UniformOutput',false));
                cond = cellfun(@(y2)(~isempty(y2)),cellfun(@(y)(regexp(y,'[Cc]ondition')),head,'UniformOutput',false));
                dur = cellfun(@(y2)(~isempty(y2)),cellfun(@(y)(regexp(y,'[Dd]isplay\W?[Tt]ime\W?((s))?')),head,'UniformOutput',false));
                label = cellfun(@(y2)(~isempty(y2)),cellfun(@(y)(regexp(y,'[Ll]abel')),head,'UniformOutput',false));
                stimname = cellfun(@(y2)(~isempty(y2)),cellfun(@(y)(regexp(y,'[Ff]ile\W?[Nn]ame')),head,'UniformOutput',false));
                
                dat{1,i} = [find(onset) find(cond) find(dur) find(label) find(stimname)];
                if ~all(dat{1,1}==[1 2 3 4 5]) % Header consistency check
                   warning(['Inconsistent header names in ' d{i}]);
                end
                dat{2,i} = t(2:end,:);
                
            end
            
            exp.runvals = runvals;
            exp.run_n = i;
            exp.dat = dat;
            
            fprintf('main.m (expset): Gathering experimental parameters.\n');
            frame = javaui(runvals);
            waitfor(frame,'Visible','off'); % Wait for visibility to be off
            s = getappdata(frame,'UserData'); % Get frame data
            java.lang.System.gc();
            
            if isempty(s)
                error('main.m (expset): User Cancelled.')
            end
            
            exp.sid = s{1};
            exp.trig = s{2};
            
            order = [];
            for i = 1:length(exp.runvals)
               order_ind = find(strcmp(s{3},exp.runvals{i}));
               if isempty(order_ind)
                   order_ind = 0; % Order entry is 0 if not included
               end
               order = [order order_ind];
            end
            avail = find(order);
            resort = order(avail);
            [~,J] = sort(resort);
            
            exp.order = avail(J);
            exp.TR = 2;
            exp.iPAT = 0; % Verify this
            exp.DisDaq = 4.75; % Verify this
            exp.f_out = [exp.sid '_out'];
            exp.durcutoff = .5;
            exp.intro = ['You will see a series of images. Please pay attention to them.\n\n\n\n' ...
                'The images will be displayed \n' ...
                'one at a time for about 5 seconds each.\n\n' ...
                'Indicate how emotionally arousing\n' ...
                'each image is by pressing a button\n' ...
                'with your right hand while the image is being displayed.\n\n\n\n' ...
                '1 (index finger) - Not Emotionally Arousing\n\n' ...
                '2 (middle finger) – A Little Emotionally Arousing\n\n' ...
                '3 (ring finger) – Moderately Emotionally Arousing\n\n' ...
                '4 (little finger) – Highly Emotionally Arousing\n\n\n' ...
                'Press any button to continue.'];

            exp.wait = 'Remain still.  The experiment is about to begin.';
            exp.wait2 = 'Remain still.  The experiment is about to begin...';
            
            % Keys
            fprintf('pres.m (pres): Defining key press identifiers...\n');
            KbName('UnifyKeyNames');
            keys.esckey = KbName('Escape');
            keys.spacekey = KbName('SPACE');
            keys.tkey = KbName('t');
            keys.key1 = KbName('1!');
            keys.key2 = KbName('2@');
            keys.key3 = KbName('3#');
            keys.key4 = KbName('4$');            
            exp.keys = keys;
            
            fprintf('main.m (expset): Storing experimental properties.\n');
            obj.exp = exp;
            
        end

        function imgload(obj)
            for i = 1:obj.exp.run_n % Each run including non selected
                if any(obj.exp.order == i) % Load available runs only
                    [~,run_dir,~] = fileparts(obj.exp.runvals{i}); % get run list directory
                    obj.image{i} = cell([size(obj.exp.dat{2,i},1) 1]); % preallocate
                    for j = 1:size(obj.exp.dat{2,i},1) % each event
                        if obj.exp.dat{2,i}{j,obj.exp.dat{1,i}(2)} % according to column index (2) cond: 1/2 = img, 0 = fix (ignore)
                            obj.image{i}{j} = imread([obj.path.images filesep run_dir filesep obj.exp.dat{2,i}{j,obj.exp.dat{1,i}(5)}]); % imread from column index (5) stimname
                        end
                    end
                end
            end
        end
        
        function addl(obj,src)
            obj.exp.lh = addlistener(src,'temp_t','PostSet',@(src,evt)tset(obj,src,evt));
        end
        
        function tset(obj,src,evt) % Corresponding to lh
            try
                obj.temp_t = evt.AffectedObject.temp_t;
            catch ME
                throw(ME);
            end
        end
        
        function cycle(obj,run)
            
            % Initialize
            rate = ' '; % Initialize blank
            rt = ' '; % Initialize blank
            t2 = [];
            keyflag = 0; % Initialize keyflag
            t0 = GetSecs;
            tic;
            i = 1;
            
            % File set-up
            fid = fopen([obj.path.out filesep obj.exp.f_out '_' int2str(run) '.csv'],'a');
            fprintf(fid,'%s,%s,%s,%s,%s,%s,%s,%s\r','Scheduled','Reported','Event','Duration','Label','Stimulus','RT','Rating');
            
            % Get first trial data
            t = obj.exp.dat{2,run}{i,obj.exp.dat{1,run}(1)};
            evt = obj.exp.dat{2,run}{i,obj.exp.dat{1,run}(2)};
            dur = obj.exp.dat{2,run}{i,obj.exp.dat{1,run}(3)};
            label = obj.exp.dat{2,run}{i,obj.exp.dat{1,run}(4)};
            stimname = obj.exp.dat{2,run}{i,obj.exp.dat{1,run}(5)};
            
            while ~obj.abort
                
                tnow = regexp(num2str(toc),'\d{1,3}','match','once'); % String conversion of time
                
                [keyIsDown,secs,keyCode]=KbCheck; % Re-occuring check
                
                % Priority 1: handle escape
                % Multiple evaluation, 0/1 time occurrence in entire loop
                if (keyIsDown==1 && keyCode(obj.exp.keys.esckey))
                    
                    if obj.debug
                        disp('----'); % Temp break
                        disp('main.m (cycle): Escape key pressed.  Aborting...') % Temp abort
                    end
                    
                    obj.abort = 1;
                    break;
                    
                end
                
                % Priority 2: handle trial presentation
                % 1-time occurence per iteration i, beginning of trial
                if str2double(tnow)==t % As long as the integer matches
                    
                    if evt
                        
                        obj.dat.img = obj.image{run}{i};
                        notify(obj,'showimg');
                        event = stimname;
                        
                        % Response duration
                        t2 = t + (dur - obj.exp.durcutoff); % Calculate when the following cut-off onset should occur
                                         
                        % Record
                        fprintf(fid,'%s,%s,%s,%s,%s,%s,',int2str(t),num2str(obj.temp_t - t0),int2str(evt),int2str(dur),label,event);
                        
                        % Start key press
                        rate = ' '; % Initialize blank
                        rt = ' '; % Initialize blank
                        keyflag = 1;
                        
                    else 
                        
                        notify(obj,'fix');
                        event = 'Fixation';
                        
                        % Record
                        fprintf(fid,'%s,%s,%s,%s,%s,%s\r',int2str(t),num2str(obj.temp_t - t0),int2str(evt),int2str(dur),label,event);                        
                    
                    end
                    
                    i = i + 1; % ***Essential to prevent racing notifications
                    
                    if i > size(obj.exp.dat{2,run},1) % Kill loop if index is greater than list size
                        break;
                    end
                    
                    if obj.debug
                        disp('----'); % Temp break
                        disp(['main.m (cycle) Scheduled: ' int2str(t)]) % Temp declared start time
                        disp(['main.m (cycle) Current: ' tnow]) % Temp reported current time
                        disp(['main.m (cycle) Reported: ' num2str(obj.temp_t - t0)]) % Temp reported start time.
                        disp(['main.m (cycle) Event Value: ' int2str(evt)]) % Temp event value
                        disp(['main.m (cycle) Stimulus: ' event]) % Temp event
                    end
                    
                    % Find next event and start time
                    t = obj.exp.dat{2,run}{i,obj.exp.dat{1,run}(1)};
                    evt = obj.exp.dat{2,run}{i,obj.exp.dat{1,run}(2)};
                    dur = obj.exp.dat{2,run}{i,obj.exp.dat{1,run}(3)};
                    label = obj.exp.dat{2,run}{i,obj.exp.dat{1,run}(4)};
                    stimname = obj.exp.dat{2,run}{i,obj.exp.dat{1,run}(5)};

                end
                                
                % Priority 3: handle cut-off fixation
                % 1-time occurrence per iteration i, end of trial
                if ~isempty(t2) % If a cut-off fixation is scheduled
                    
                    tnow2 = regexp(num2str(toc),'\d{1,3}.\d{1}','match','once'); % String conversion of time
                   
                    if str2double(tnow2)==t2 % Match duration cut-off
                        
                        % Record response at end of trial
                        fprintf(fid,'%s,%s\r',rt,rate);
                        keyflag = 0;
                        
                        notify(obj,'fix');
                        event = 'Fixation';
                        t2 = []; % Remove from schedule
                        
                        if obj.debug
                            disp('----'); % Temp break
                            disp(['main.m (cycle) Scheduled: ' num2str(t2)]) % Temp declared start time
                            disp(['main.m (cycle) Current: ' tnow2]) % Temp reported current time
                            disp(['main.m (cycle) Reported: ' num2str(obj.temp_t - t0)]) % Temp reported start time.
                            disp('main.m (cycle) Event Value: Cut-off fixation') % Temp event value
                            disp(['main.m (cycle) Stimulus: ' event]) % Temp event
                        end
                        
                    end
                end
                
                % Priority 4: handle rating response
                % Multiple evaluation until key press, 0/1 time occurrence per iteration i
                if keyflag
                    
                    if keyIsDown
                        
                        switch find(keyCode,1)
                            case obj.exp.keys.key1
                                rate = '1';
                            case obj.exp.keys.key2
                                rate = '2';
                            case obj.exp.keys.key3
                                rate = '3';
                            case obj.exp.keys.key4
                                rate = '4';
                        end
                        
                        rt = num2str(secs - obj.temp_t); % temp_t doesn't change until next presentation.
                        keyflag = 0; % Reset keyflag
                        
                        if obj.debug
                            disp(['main.m (cycle) Key pressed: ' int2str(find(keyCode))]) % Temp notification
                            disp(['main.m (cycle) RT: ' rt]) % Temp RT
                            disp(['main.m (cycle) Rate: ' rate]) % Temp rate
                        end
                        
                    end
                    
                end

            end
            
            fclose(fid);
            Screen('Flip',obj.monitor.w); % Clear screen.
        end
        
    end
    
end