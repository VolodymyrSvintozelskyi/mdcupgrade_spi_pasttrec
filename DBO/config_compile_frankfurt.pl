Familyname  => 'ECP5UM',
Devicename  => 'LFE5UM-45F',
Package     => 'CABGA381',
Speedgrade  => '8',


TOPNAME                      => "mdctdc",
lm_license_file_for_synplify => "27020\@jspc29", #"27000\@lxcad01.gsi.de";
lm_license_file_for_par      => "1710\@jspc29",
lattice_path                 => '/d/jspc29/lattice/diamond/3.11_x64',
synplify_path                => '/d/jspc29/lattice/synplify/O-2018.09-SP1/',

nodelist_file                => '../nodelist_frankfurt.txt',
pinout_file                  => 'dbo',
par_options                  => '../par.p2t',


#Include only necessary lpf files
include_TDC                  => 0,
include_GBE                  => 0,

#Report settings
firefox_open                 => 0,
twr_number_of_errors         => 20,
no_ltxt2ptxt                 => 1,  #if there is no serdes being used
