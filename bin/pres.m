classdef pres < handle
    % pres.m class for ecig.m
    % See dated ReadMe file
    
    properties
        movie
        txt
        fix_color
        misc
        keys
        lh
    end
    
    properties (SetObservable)
        temp_t
        abort = 0;
    end
    
    methods
        function obj = pres(src)
                        
            % Function handles
            fprintf('pres.m (pres): Defining presentation function handles...\n');
            misc.fix1 = @(monitor,color)(Screen('DrawLine',monitor.w,color,monitor.center_W-20,monitor.center_H,monitor.center_W+20,monitor.center_H,7));
            misc.fix2 = @(monitor,color)(Screen('DrawLine',monitor.w,color,monitor.center_W,monitor.center_H-20,monitor.center_W,monitor.center_H+20,7));
            misc.text = @(monitor,txt)(DrawFormattedText(monitor.w,txt,'center','center',monitor.white));
            
            % Keys
            fprintf('pres.m (pres): Defining key press identifiers...\n');
            KbName('UnifyKeyNames');
            keys.esckey = KbName('Escape');
            keys.spacekey = KbName('SPACE');
            keys.tkey = KbName('t');
            
            % Listeners
            fprintf('pres.m (pres): Defining listener function handles...\n');
            lh.lh1 = addlistener(src,'fix',@(src,evt)dispfix(obj,src,evt));
            lh.lh2 = addlistener(src,'playback',@(src,evt)videoplayback(obj,src,evt));
            lh.lh3 = addlistener(src,'txt',@(src,evt)disptxt(obj,src,evt));
            lh.lh4 = addlistener(src,'dat','PostSet',@(src,evt)propset(obj,src,evt));
            
            fprintf('pres.m (pres): Storing object properties...\n');
            obj.misc = misc;
            obj.keys = keys;
            obj.lh = lh;
            
            fprintf('pres.m (pres): Success!\n');
        end
        
        function dispfix(obj,src,evt) % Corresponding to lh1
            obj.misc.fix1(src.monitor,obj.fix_color);
            obj.misc.fix2(src.monitor,obj.fix_color);
            obj.temp_t = Screen('Flip',src.monitor.w);
        end
        
        function showimg(obj,src,evt) % Corresponding to lh2
            
        end
        
        function disptxt(obj,src,evt) % Corresponding to lh3
            obj.misc.text(src.monitor,obj.txt);
            obj.temp_t = Screen('Flip',src.monitor.w);
        end
        
        function propset(obj,src,evt) % Corresponding to lh4
            try
                f = fieldnames(evt.AffectedObject.dat);
                for i = 1:length(f)
                    obj.(f{i}) = evt.AffectedObject.dat.(f{i});
                end
            catch ME
                throw(ME);
            end
        end
    end
    
end

