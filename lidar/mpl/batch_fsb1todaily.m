function [status,polavg] = batch_fsb1todaily(mpl_inarg);
% [status,polavg] = batch_b1todaily(mpl_inarg);
% Processes "mplpol.b1" file into daily mat files.
% Takes an input argument with the following fields:
%    mpl_inarg.in_dir
%    mpl_inarg.tla  Typically 3-letter site designation, but also IOP names
%    mpl_inarg.fstem = [mpl_inarg.tla,'_mplpol_3flynn.'];
%    mpl_inarg.out_dir = [mpl_inarg.in_dir, 'out',filesep];
%    mpl_inarg.bad_dir = [mpl_inarg.out_dir,'..',filesep, 'bad',filesep];
%    mpl_inarg.mat_dir = [mpl_inarg.out_dir,'..',filesep, 'mat',filesep];
%    mpl_inarg.fig_dir = [mpl_inarg.out_dir,'..',filesep, 'fig',filesep];
%    mpl_inarg.png_dir = [mpl_inarg.out_dir,'..',filesep, 'png',filesep];
%    mpl_inarg.Nsecs = 120; Number of seconds to average over
%    mpl_inarg.Nrecs = 10000; Number of netcdf records to read at a time
%    mpl_inarg.dtc = eval(['@dtc_',mpl_inarg.tla,'_']); %accept and return MHz
%    mpl_inarg.ap = eval(['@ap_',mpl_inarg.tla,'_']); %accept range, return .cop, .crs
%    mpl_inarg.ol_corr = eval(['@ol_',mpl_inarg.tla,'_']); % accept range, return ol_corr
%    mpl_inarg.cop_snr = 2; Minimum copol snr threshold for bscat image mask
%    mpl_inarg.ldr_snr = 1.5; Minimum linear dpr threshold for ldr image mask
%    mpl_inarg.ldr_error_limit = .25; Max ldr error fraction for ldr image mask
%    mpl_inarg.fig = gcf;
%    mpl_inarg.vis = 'on';
%    mpl_inarg.cv_log_bs = [1.5,4.5];
%    mpl_inarg.plot_ranges = [15,5,2];

% Uses ancload_coords and ancloadpart to break the incoming netcdf file into pieces

status = 0;
if ~exist('mpl_inarg','var')
   mpl_inarg = define_mpl_inarg;
else
   mpl_inarg = populate_mpl_inarg(mpl_inarg);
end

%prepare output directories
in_dir = mpl_inarg.in_dir;
out_dir = mpl_inarg.out_dir;
mat_dir = mpl_inarg.mat_dir;
bad_dir = mpl_inarg.bad_dir;
% in_dir = ['C:\case_studies\ISDAC\MPL\MPL_raw\'];

if ~exist(out_dir, 'dir')
   mkdir(out_dir);
end
if ~exist(mat_dir, 'dir')
   mkdir(mat_dir);
end
if ~exist(bad_dir, 'dir')
   mkdir(bad_dir);
end

in_files = dir([in_dir,'*mpl*.nc']);
in_files_ = dir([in_dir,'*mpl*.cdf']); 
in_files = [in_files;in_files_];

for d = length(in_files):-1:1
   tmp = fliplr(in_files(d).name);
   [dmp,tmp] = strtok(tmp,'.');
   [tmp1,tmp] = strtok(tmp,'.');
   [tmp2,dmp] = strtok(tmp,'.');
   tmp = fliplr([tmp1,'.',tmp2]);
   
   dates(d) = datenum(tmp,'yyyymmdd.HHMMSS');
end
[ds, ind] = sort(dates);

out_files = dir([out_dir,'*.nc.out']);
% out_files = [];
for m = 1:length(in_files)
   done = false;
   %    for n = 1:length(out_files);
   n = 1;
   while ~done&&n<=length(out_files)
      done = strcmp([in_files(ind(m)).name,'.out'],out_files(n).name);
      if ~done
         n = n+1;
      else
         out_files(n) = [];
      end
   end
   if ~done
      tic
%Suggested addition: try to read next netcdf file, if there is an error 
% then copy it to the bad directory and move on.
%       fid_out = fopen([out_dir,in_files(ind(m)).name,'.out'],'w');
%       fclose(fid_out);
      disp(['Reading ',in_files(ind(m)).name]);
      anc_mplpol_ = anc_loadcoords([in_dir,in_files(ind(m)).name]);
      status = status + 1;
      for mm = 1:mpl_inarg.Nrecs:length(anc_mplpol_.time)
         disp(['netcdf record: ',num2str(mm),' of ',num2str(length(anc_mplpol_.time))]);
         anc_mplpol = anc_loadpart(anc_mplpol_,mm,mpl_inarg.Nrecs);

         try
            if exist('anc_mplpol_tail','var')
            anc_mplpol = anc_cat(anc_mplpol_tail,anc_mplpol);
            end
         catch
            fid_bad = fopen([bad_dir,in_files(ind(m)).name,'.bad'],'w');
            fclose(fid_bad);
         end
         if ~isempty(anc_mplpol)
            [polavg_new,tail_ind] = proc_mplpolfsb1_5(anc_mplpol,mpl_inarg);
            anc_mplpol_tail = anc_sift(anc_mplpol,[tail_ind:length(anc_mplpol.time)]);
            if exist('polavg','var')&&length(polavg.time)>1
               polavg = catpol(polavg,polavg_new);
            else
               polavg = polavg_new;
            end
            clear polavg_new;
            date_m = min([floor(ds(m)),floor(polavg.time(1))]);
            [polavg, nextavg] = splitpol(polavg, polavg.time>(1+date_m));
            if length(nextavg.time)>2 && length(polavg.time)>2
               fout_name = [mpl_inarg.fstem,datestr(date_m,'yyyymmdd'),'.doy',num2str(serial2doy(date_m)),'.mat'];
               save([mat_dir, fout_name],'polavg', '-mat');
               %                plot_pol_lin_bs(polavg,mpl_inarg);
               polavg = plot_pola_log_bs(polavg,mpl_inarg);
               if isfield(polavg,'inarg')
                  mpl_inarg = polavg.inarg; mpl_inarg.manual_limits = false;
                  polavg = rmfield(polavg,'inarg');
               end
               if isfield(mpl_inarg,'assess_ray')&&mpl_inarg.assess_ray
                  assess_mpl_ray(polavg,mpl_inarg);
               end
               polavg = nextavg;
               nextavg = [];
               close('all');
            end
         else
            disp('Skipping empty file')
         end
         
      end % of 'for m' loop
   toc
   end
   
end
status = status + 1;
%%

while length(polavg.time>1)
   date_m = floor(polavg.time(1));
   [polavg, nextavg] = splitpol(polavg, polavg.time>(1+date_m));
   if length(polavg.time)>1
      fout_name = [mpl_inarg.fstem,datestr(date_m,'yyyymmdd'),'.doy',num2str(serial2doy(date_m)),'.mat'];
      save([mat_dir, fout_name],'polavg', '-mat');  
      polavg = plot_pola_log_bs(polavg,mpl_inarg);
%       plot_pol_lin_bs(polavg,mpl_inarg);
      if isfield(polavg,'inarg')
         mpl_inarg = polavg.inarg; mpl_inarg.manual_limits = false;
         polavg = rmfield(polavg,'inarg');
      end
      if isfield(mpl_inarg,'assess_ray')&&mpl_inarg.assess_ray
         assess_mpl_ray(polavg,mpl_inarg);
      end
      polavg = nextavg;
      nextavg = [];
   end
end
disp('done!')
%%

return

function mpl_inarg = define_mpl_inarg
in_file = getfullname('*mpl*.nc;*mpl*.cdf;','mpl_data','Select an MPL netcdf file in th directory to process...');
if iscell(in_file)
   in_file = in_file{1};
end
[in_dir, fname, ext] = fileparts(in_file); in_dir = [in_dir, filesep]; fname = [fname ext];
anc_ = anc_link(in_file);

 mpl_inarg.in_dir = in_dir;
%    mpl_inarg.in_dir = getdir('mpl_data','Select directory containing mplpol b1 data');
%    rid_ni = fliplr(mpl_inarg.in_dir(1:end-1));
%    tok = strtok(rid_ni,filesep);
%    kot = fliplr(tok);
%    mpl_inarg.tla = kot(1:3); % Typically 3-letter site designation, but also IOP names
%    mpl_inarg.tla = 'ufo'
fac = strtok(fname, '.'); sss = fac(1:3); fac(1:3) = [];
while ~isempty(fac) &&(~strcmp(fac(1),upper(fac(1))))
   fac(1) = [];
end
   mpl_inarg.tla = [sss fac];
   mpl_inarg.fstem = [mpl_inarg.tla,'_mplpol_3flynn.'];
   mpl_inarg.out_dir = [mpl_inarg.in_dir, 'out',filesep];
   mpl_inarg.bad_dir = [mpl_inarg.out_dir,'..',filesep, 'bad',filesep];
   mpl_inarg.mat_dir = [mpl_inarg.out_dir,'..',filesep, 'mat',filesep];
   mpl_inarg.fig_dir = [mpl_inarg.out_dir,'..',filesep, 'fig',filesep];
   mpl_inarg.png_dir = [mpl_inarg.out_dir,'..',filesep, 'png',filesep];
   
   mpl_inarg.Nsecs = 90;
   mpl_inarg.Nrecs = 10000;
   mpl_inarg.manual_limits = true;
   if isfield(anc_.vatts,'afterpulse_correction_height')
      mpl_inarg.ap_in_file = true;
   end
   mpl_inarg.assess_ap = false;
   mpl_inarg.replace_ap = false;
   
   if isfield(anc_.vatts,'deadtime_correction')
      mpl_inarg.dtc_in_file = true;
   end
      if isfield(anc_.vatts, 'overlap_correction')
      mpl_inarg.ol_corr_in_file = true;
   end
   mpl_inarg.replace_ol = false;
   mpl_inarg.assess_ray = true;
   mpl_inarg.dtc = eval(['@dtc_',mpl_inarg.tla,'_']); %accept and return MHz
   mpl_inarg.ap = eval(['@ap_',mpl_inarg.tla,'_']); %accept range, return .cop, .crs
   mpl_inarg.ol_corr = eval(['@ol_',mpl_inarg.tla,'_']); % accept range, return ol_corr
   
   mpl_inarg.cop_snr = 4;% larger numbers eliminate data
   mpl_inarg.ldr_snr = 5;% larger numbers eliminate data
   mpl_inarg.ldr_error_limit = 1; %smaller numbers eliminate data
   fig = 1; 
   while isgraphics(fig)
      fig = fig+1;
   end
   mpl_inarg.fig = fig;
   mpl_inarg.vis = 'on';
   mpl_inarg.cv_log_bs = [2,4];
   mpl_inarg.cv_dpr = [-2.5,0];
   mpl_inarg.plot_ranges = [15,10,5,2];
return
function mpl_inarg = populate_mpl_inarg(mpl_inarg);
   if ~isfield(mpl_inarg,'in_dir')
      mpl_inarg.in_dir = getdir('mpl_data','Select directory containing mplpol b1 data');
   end
   if ~isfield(mpl_inarg,'tla')
      mpl_inarg.tla = 'ufo';
   end
   if ~isfield(mpl_inarg,'fstem')
      mpl_inarg.fstem = [mpl_inarg.tla, '_mplpol_3flynn'];
   end
   if ~isfield(mpl_inarg,'out_dir')
      mpl_inarg.out_dir = [mpl_inarg.in_dir, 'out',filesep];
   end
   if ~isfield(mpl_inarg,'bad_dir')
      mpl_inarg.bad_dir = [mpl_inarg.out_dir,'..',filesep, 'bad',filesep];
   end
   if ~isfield(mpl_inarg,'mat_dir')
      mpl_inarg.mat_dir = [mpl_inarg.out_dir,'..',filesep, 'mat',filesep];
   end
   if ~isfield(mpl_inarg,'fig_dir')
      mpl_inarg.fig_dir = [mpl_inarg.out_dir,'..',filesep, 'fig',filesep];
   end
   if ~isfield(mpl_inarg,'png_dir')
      mpl_inarg.png_dir = [mpl_inarg.out_dir,'..',filesep, 'png',filesep];
   end
   if ~isfield(mpl_inarg,'dtc');
      mpl_inarg.dtc = eval(['@dtc_',mpl_inarg.tla,'_']); %accept and return MHz
   end
   if ~isfield(mpl_inarg,'ap');
      mpl_inarg.ap = eval(['@ap_',mpl_inarg.tla,'_']); %accept range, return .cop, .crs
   end
   if ~isfield(mpl_inarg,'ol_corr');
      eval(['@ol_',mpl_inarg.tla,'_']); % accept range, return ol_corr
   end   
   if ~isfield(mpl_inarg,'Nsecs');
      mpl_inarg.Nsecs = 150; % This is the number of seconds to average over
   end   
   if ~isfield(mpl_inarg,'Nrecs');
      mpl_inarg.Nrecs = 2500; % This is the number of netcdf records to read at a time.
   end   
   if ~isfield(mpl_inarg,'cop_snr');
      mpl_inarg.cop_snr = 2.5;
   end
   if ~isfield(mpl_inarg,'ldr_snr');
      mpl_inarg.ldr_snr = 2.5;
   end
   if ~isfield(mpl_inarg,'ldr_error_limit');
      mpl_inarg.ldr_error_limit = 0.5;
   end
   if ~isfield(mpl_inarg,'vis');
      mpl_inarg.vis = 'on';
   end
   if ~isfield(mpl_inarg,'cv_log_bs');
      mpl_inarg.cv_log_bs = [0,4];
   end   

return