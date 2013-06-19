classdef main < handle
    % main.m class for npsd.m
    % See dated ReadMe file
    
    properties
        exec = 'default'; % Execute type, associated with bin files
        monitor
        path
        exp
        movie
        temp_t
        abort = 0;
        mov
    end
    
    properties (SetObservable)
       dat
    end
    
    events
       fix
       playback
       txt
    end
    
    methods (Static)
        function [monitor] = disp()
            % Find out screen number.
            debug = 1;
            if debug
                %                 whichScreen = max(Screen('Screens'));
                whichScreen = 1;
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
            
            exp.order = order;
            exp.TR = 2;
            exp.iPAT = 0; % Verify this
            exp.DisDaq = 4.75; % Verify this
            
            exp.wait = 'Remain still.  The experiment is about to begin.';

            fprintf('main.m (expset): Storing experimental properties.\n');
            obj.exp = exp;
            
        end

        function videoload(obj) % Requires open window in obj.monitor and content path
        end
        
        function addl(obj,src)
            obj.exp.lh = addlistener(src,'temp_t','PostSet',@(src,evt)tset(obj,src,evt));
            obj.exp.lh2 = addlistener(src,'abort','PostSet',@(src,evt)abortcycle(obj,src,evt));
        end
        
        function tset(obj,src,evt) % Corresponding to lh
            try
                obj.temp_t = evt.AffectedObject.temp_t;
            catch ME
                throw(ME);
            end
        end
        
        function abortcycle(obj,src,evt) % Corresponding to lh2
            try
                obj.abort = evt.AffectedObject.abort;
            catch ME
                throw(ME);
            end
        end
        
        function cycle(obj,run)
            % Initialize
            t0 = GetSecs;
            tic;
            i = 1;
            
            fid = fopen([obj.path.out filesep obj.exp.f_out],'a');
            fprintf(fid,'%s,%s,%s\r','Event','Scheduled','Reported');
            
            evt = obj.exp.build.seq(obj.exp.seq).run(run).pres{i};
            t = obj.exp.build.seq(obj.exp.seq).run(run).t{i};
            
            while ~obj.abort
                tnow = regexp(num2str(toc),'\d{1,3}','match','once'); % String conversion of time
                
                if strcmp(tnow,t) % As long as the integer matches
%                     disp(evt) % Temp event
%                     disp(t) % Temp declared start time
%                     disp(tnow) % Temp reported current time
                    if strcmp(evt,'end')
                        break;
                    elseif strcmp(evt,'fix')
                        notify(obj,'fix');
                    elseif ~isempty(regexp(evt,'.mov', 'once'))
                        obj.dat.movie = obj.movie(strcmp(evt,obj.mov));
                        notify(obj,'playback')
                    else
                        break;
                    end
%                     disp(obj.temp_t - t0) % Temp reported start time.
                    i = i + 1; % ***Essential to prevent racing notifications
                    
                    fprintf(fid,'%s,%s,%s\r',evt,t,num2str(obj.temp_t - t0));
                    
                    % Find next event and start time
                    evt = obj.exp.build.seq(obj.exp.seq).run(run).pres{i};
                    t = obj.exp.build.seq(obj.exp.seq).run(run).t{i};
                end
            end
            
            fclose(fid);
            Screen('Flip',obj.monitor.w); % Clear screen.
        end
        
    end
    
end

