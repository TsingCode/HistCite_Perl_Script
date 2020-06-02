#!/usr/local/ActivePerl-5.8/bin/perl -w
#-d:DProf
#!/usr/bin/perl -w
$VERSION = \'12.03.17';
$BG_COLOR = '#fff';
BEGIN {
    Win32::SetChildShowWindow(0) if defined &Win32::SetChildShowWindow;
}
$STD = qq(<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">);
$STD .= qq(<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />);
sub guide {my $tag = shift||''; return "<a href=# OnClick=\"opener.top.glossary(); return false\">Glossary</a>&nbsp;&nbsp;<a href=\"http://www.histcite.com/HTMLHelp/guide.html#$tag\" target=guide>HistCite Guide</a>"; }

print "HistCite $$VERSION\n";

use Local;
use Settings;
use SysInfo;
use HC::Tips;
require "glossary.html";
require "about.html";
require "stopwd";	$stopwd{A} = 1;
require "state";	$state{AK} = 1;
require "Unions";
require "help-html";
require "help-map";
require "ajax2.js";
require "addfile";
#use diagnostics;
use HTML::Entities;
use Cwd qw(cwd realpath);
use File::Glob ':glob';
use File::Basename;
use HTTP::Daemon;
use HC::HTTP::Daemon;
use HTTP::Status;
#use URI::Escape;
use CGI;
#use GD;
use GraphViz;
use HC::Data;
use HC::Graphviz;
#use Data::Dumper;
#use Benchmark qw(:all :hireswallclock);
use POSIX qw(strftime uname);

$ENV{PATH} .= ';./att' if ('MSWin32' eq $^O and not $PerlApp::VERSION);

$TmpPath = GetTempPath();

if($PerlApp::VERSION) {
	$HistCiteHome = dirname(PerlApp::exe());
	$LogPath = $ENV{APPDATA} ? "$ENV{APPDATA}/HistCite" : $HistCiteHome;
	unless(-d $LogPath) {
		mkdir $LogPath or $LogPath = $HistCiteHome;
	}
} else {
	#refine this side later; also for Unix above
	$HistCiteHome = (cwd);
	$LogPath = $HistCiteHome;
}
$tf = "$LogPath/test" . time();
if(open F, ">$tf") {
	close F; unlink $tf;
} else {
	$LogPath = $TmpPath;
	$LogWarn = "N.B. The logs and HistCite.conf are in a temporary location.";
}

keys(%{$hra}) = 512;
keys(%{$hrA}) = 512;
%{$hrm} = (); $MARKS = 0; $PAGER{mark} = 'tl'; @{$pager{mark}} = ();
%{$hrt} = (); $PAGER{temp} = 'tl'; @{$pager{temp}} = ();
$hr{main} = $hra;
$hr{mark} = $hrm;
$hr{temp} = $hrt;
%main = qw(main 1 mark 1 temp 1);
%modcsv = qw(au 1 so 1 wd 1 py 1 dt 1 la 1 in 1 i2 1 co 1 tg 1);
$hr{au} = \%au; $ari{au} = \@aui;
$hr{so} = \%jn; $ari{so} = \@jni;
$hr{or} = \%or; $ari{or} = \@ori;
$hr{ml} = \%ml; $ari{ml} = \@mli;
$hr{wd} = \%wd; $ari{wd} = \@wdi;
$hr{tg} = \%tg; $ari{tg} = \@tgi; $TAGS = 0;
for my $m qw(py dt la in i2 co) { $ari{$m} = [] }
for my $m (@all_mod) { $PAGER{$m} = 'pubs' }
$PAGER{py} = 'name'; $PAGER{main} = '';
@tl = ();
%isbook = ();
%g = ();
%istag = ();

s_sets_init();
g_vars_init();
m_sets_init();

$$title = '';
$$title_line = '';
$$caption = '';
$MNB = '';
$MORIGINAL = '';
$net_tgcs = 0; $net_tlcs = 0; $net_tncr = 0; $net_tna = 0;
$HELPTIP_COLOR = '#ffff77';
$SORT_COLOR = '#904644'; #ffd363 #a22 #a52829 brown #f66 #b8693d #905644
$FOUND_COLOR = '#beb'; #b5efbd #c6dbff
$MENU_COLOR = '#d3d3d3';
$DIM_COLOR = '#7b7b7b';
$TABLE_BORDER_COLOR = '#cccccc';
$TH_COLOR = '#e1e9e1';
$TR_ODD_COLOR = '#eeeeee';
$TR_EVN_COLOR = '#dddddd';
#$VERBOSE_LOG = 0;
$win_opts = "'resizable=yes,scrollbars=yes'";
$empty_list = '<div align=center style="margin-top:20px;"><i>The list is empty</i></div>';
$esclose = <<"";
<SCRIPT>document.onkeydown = function (e) { e = e ? e : event ? event : null;
	if(e) if(e.keyCode==27) close();
}</SCRIPT>

$Start = 1;
$LIVE = 1;
get_cmd_args(@ARGV);

if($HOST_AS_NAME) {
    $host = 'localhost';
} else {
    $host = '127.0.0.1';
}
$PortFile = "$LogPath/HistCite.run";

if(another_session_runs()) {
	$PortFile = '';
	exit;
}
$port = 1924;
$port = start_daemon();

print <<"";
\nDO NOT CLOSE THIS WINDOW. If you do, HistCite will cease to function.
\nIf your browser does not start automatically, please,
open it manually and enter the following address: http://$host:$port/\n

create_logs();
$ConfFile = "$LogPath/HistCite.conf";

if(open RUN, ">$PortFile") {
	print RUN $port;
	close RUN;
} else {
	my_error(\"Cannot save run state to '$PortFile':\n$!");
	exit;
}

print LOG load_conf(), "\n";
test_temp();

$path = @cmd_file ? 'input' : '';
$start_path = "http://$host:$port/$path";

@conn_cache = (Connection => 'close', 
	Expires => 'Mon, 01 Jan 1990 00:00:00 GMT', Cache_control => 'no-cache');
$h = new HTTP::Headers Content_type => 'text/html', @conn_cache;
sub h_file {
	my $ext = shift||'txt';
	my $file = basename($file[0]||'export');
	$file =~ s/\..*?$//;
	return new HTTP::Headers Content_type => 'Application/octet-stream', 
	Content_disposition => qq(attachment; filename="$file.$ext"), @conn_cache;
}
$hi_msie = '<!-- special Microsoft Internet Explorer, burst buffer hack -->'
	. (' 'x555) .'<!--- end of MSIE buffer hack -->';

start_browser($browser, $start_path);

$pos_fixed = $IE6 ? 'absolute' : 'fixed';
$UA_last = '';
$uaIE7 = $uaIE8 = 0;

while(my $c = $daemon->accept) {
	#print "\tprocessing new client .. \n";
	#$client_time = time();
	while(my $r = $c->get_request) {
		local $UA = $r->header('user-agent');
		if($UA_last ne $UA) {
			print LOG "$UA\n";
			$UA_last = $UA;
			$uaIE7 = $UA =~ /MSIE 7/ ? 1 : 0;
			$uaIE8 = $UA =~ /MSIE 8/ ? 1 : 0;
		}
		my $path = $r->url->path;
		#print "\t\tprocessing new request: '$path'\n";
		my $query = $r->url->query;
		my $content = ('POST' eq $r->method ? $r->content() : $query);
		my $q = new CGI($content) if defined $content;
		if($q) {
			$VIEW = $q->param('VIEW')
				if $q->param('VIEW') and $view{$q->param('VIEW')};
			if($q->param('showmm')) {
				$m_mark_menu_show = 1 if 'ON' eq $q->param('showmm');
				$m_mark_menu_show = 0 if 'OFF' eq $q->param('showmm');
			} elsif($q->param('showem')) {
				$m_edit_menu_show = 1 if 'ON' eq $q->param('showem');
				$m_edit_menu_show = 0 if 'OFF' eq $q->param('showem');
			} elsif($q->param('showsf')) {
				$m_search_form_show = 1 if 'ON' eq $q->param('showsf');
				$m_search_form_show = 0 if 'OFF' eq $q->param('showsf');
			} elsif($q->param('showicr')) {
				$m_records_show = 1 if 'ON' eq $q->param('showicr');
				$m_records_show = 0 if 'OFF' eq $q->param('showicr');
			} elsif($q->param('showai')) {
				$m_ai_show = 1 if 'ON' eq $q->param('showai');
				$m_ai_show = 0 if 'OFF' eq $q->param('showai');
			} elsif($q->param('showgo')) {
				$m_go_show = 1 if 'ON' eq $q->param('showgo');
				$m_go_show = 0 if 'OFF' eq $q->param('showgo');
			}
			$m_form_on = $m_mark_menu_show || $m_edit_menu_show;
			$change_sort_order = $q->param('rev') ? 1 : 0;
		} else {
			$change_sort_order = 0;
		}

		if('/input' eq $path) {
			if($q or @cmd_file) {
				my @f = ();
				if($q) {
					my $in = $q->param('inputpath');
					@f = glob $in if $in;
				} else {
					@f = @cmd_file;
					undef @cmd_file;
				}
				$c->hc_send_cont_head();
				unless( read_batch(\@f, $c) ) {
					my $o = '</pre><p><a href=/ style=text-decoration:none;>&nbsp; OK</a>'
						.'&nbsp; &nbsp;<a href=javascript:history.back() style=text-decoration:none;>Back</a>';
					$o .= "<SCRIPT>men.style.display='';</SCRIPT>";
					print $c $o;
				}
			} else {
				$c->send_redirect("http://$host:$port/", 302);
			}

		} elsif('/alive' eq $path) {
			$c->send_response(new HTTP::Response(200,'OK',$h,'ok'));
			start_browser($browser, "http://$host:$port/");
			print LOG 'New browser switch (', scalar localtime, ")\n";

		} elsif($path =~ m!/graph/?(\w+)*/(py|dt|la|in|in2|co)/(\d+).html!) {
			my $cat = ($1 ? $1 : 'item');
			my $hr = $higram{$2}->{$cat};
			my $item = $higram{$2}->{index}[$3];
			$c->send_response(new HTTP::Response(200,'OK',$h,${lister2html($hr,$item,$2)}));
		} elsif($path =~ m!/graph/histo_(pyX|py|pt|dt|la|in|in2|co).html!) {
			mark_histo_form($q, $1) if $q and $q->param('actin');
			$c->send_response(new HTTP::Response(200,'OK',$h,histogram_as_html($1)));

		} elsif('/graph/GraphMaker' eq $path) {
			if($q) {
				g_vars_set($q);
				if('Export to file' eq $q->param('action')) {
					if('pajek1' eq $q->param('format')) {
						$c->send_response(new HTTP::Response(200,'OK',h_file('net'),a2pajek()));
					} elsif('pajek2' eq $q->param('format')) {
						$c->send_response(new HTTP::Response(200,'OK',h_file('net'),a2pajek(1)));
					} elsif('DOT' eq $q->param('format')) {
						if($gc->{img}) {
							# need to make this independent
							if(404 == $c->hc_send_file_attach("$Gtmp-0.dot",'HistCite Historiograph file.dot')) {
								print LOG "$Gtmp-0.dot gone?\n";
								$c->send_response(new HTTP::Response(200,'OK',$h,'Please, re-make graph.'));
							}
						} else {
							$c->send_response(new HTTP::Response(200,'OK',$h,'Please, make graph first.'));
						}
					}
				} else {
					my $t = time();
					my $r = a2graph();
					$t = time() - $t;
					print LOG " done in $t secs.\n";
					if($r) {
						$c->send_response(new HTTP::Response(200,'OK',$h,g2frames(0)));
					} else {
						$c->send_response(new HTTP::Response(200,'OK',$h,'There was a problem making graph.  Please see log for details.'));
					}
				}

			} else {
				$c->send_response(new HTTP::Response(200,'OK',$h,GraphMaker_frames()));
			}
			$c->force_last_request();

		} elsif('/graph/pane' eq $path) {
			my $g = defined $Gtmp ? 0 : -1;
			$c->send_response(new HTTP::Response(200,'OK',$h,g2frames($g)));

		} elsif('/graph/gm' eq $path) {
			if($q) {
				g_vars_init();
			}
			$c->send_response(new HTTP::Response(200,'OK',$h,gm()));

		} elsif('/graph/0.html' eq $path) {
			$c->send_response(new HTTP::Response(200,'OK',$h,g_img2frame()));
		} elsif('/graph/info-0.html' eq $path) {
			$c->send_response(new HTTP::Response(200,'OK',$h,g_info2frame()));
		} elsif('/graph/gmenu' eq $path) {
			$c->send_response(new HTTP::Response(200,'OK',$h,g_menu2frame()));

		} elsif($path =~ m!/graph/(\d+).(png|jpg|ps)!) {
			my $gr = ($1 ? $g{$1} : $gc);
			my $ftype = $2;
			if('ps' eq $ftype) {
				$c->hc_send_file_attach("$Gtmp-$1.ps", 'HistCite historiograph.ps');
			} else {
				$c->hc_send_file_attach("$Gtmp-$1.$ftype", '', "image/$ftype");
			}

		} elsif ($r->url =~ /savehtmlestimate/) {
			$c->send_response(new HTTP::Response(200,'OK',$h,do_save_html_estimate()));

		} elsif ($r->url =~ /savehtml/) {
			my $er = '';
			my $net = do_save_html(\$er);
			if($net) {
				$net = realpath($net);
				my $o = '';
				add_body_script(\$o, 'ui');
				$o .=<<"";
HTML output saved to $net<br>Click <a href="file://$net">here</a> (if the browser allows) to browse it now.

				$c->send_response(new HTTP::Response(200,'OK',$h,$o));
			} else {
				$c->send_response(new HTTP::Response(200,'OK',$h,qq(<pre>$er<p><a href=javascript:close()>OK</a></pre>)));
			}

		} elsif ($r->url eq '/keepgraph') {
			if(defined $q and 'keepgraph' eq $q->param('cmd')) {
				my $t = $q->param('title');
				my $d = $q->param('desc');
				keep_graph($t, $d);
				my $o = '';
				add_body_script(\$o, 'ui');
				$o .=<<"";
The graph was saved for future reference.  It can be viewed from the Historiographs page.<p><b>Title</b>: $t<p><b>Description</b>: $d
<SCRIPT>setTimeout('close()', 3000);</SCRIPT></BODY>

				$c->send_response(new HTTP::Response(200,'OK',$h,$o));
			} else {
				$c->send_response(new HTTP::Response(200,'OK',$h,keep_graph_dialog()));
			}

		} elsif ($r->url =~ /\?cmd=savenow/) {
			my $path = "http://$host:$port". $q->param('url');
			my $net = do_save_export($hra);
			if($net) {
				# need to change this to test if source is readonly then bakup to temp
				if($FILENOW && rename($FILENOW, "$FILENOW.bak") or $title_file) {
					my $file_path;
					(undef, $file_path, undef) = fileparse($file[0]||'any', '\..*');
					$FILENOW ||= $title_file ? "$file_path$title_file.hci" : "untitled.hci";
					if(my_cp($net, $FILENOW)) {
						$NEEDSAVE = 0;
						$title_file = basename($FILENOW);
						$$title = $title_file;
						$c->send_redirect("$path?${\(time)}", 302);
					} else {
						$c->send_response(new HTTP::Response(200,'OK',$h,
							"Failed to write out $FILENOW.<br>Backup file: $FILENOW.bak"
							."<p>If problems persist, please report.  <a href=$path>OK</a>"));
					}
				} else {
					$c->send_response(new HTTP::Response(200,'OK',$h,
						"Failed to backup $FILENOW."
						."<p>If problems persist, please report.  <a href=$path>OK</a>"));
				}
				unlink $net;
			} else {
				$c->send_response(new HTTP::Response(200,'OK',$h,"There was a problem creating a temporary file.  See log for details.  <a href=javascript:history.go(-1)>OK</a>"));
			}

		} elsif ($r->url =~ /\?cmd=save(mark|main|temp)/) {
			my $net = do_save_export($hr{$1});
			if($net) {
				$c->hc_send_file_attach($net,'HistCite export file.hci');
				unlink $net;
				$NEEDSAVE = 0 unless $FILENOW;
			} else {
				$c->send_response(new HTTP::Response(200,'OK',$h,"There was a problem creating a temporary file.  See log for details.  <a href=javascript:history.go(-1)>OK</a>"));
			}

		} elsif ($r->url =~ /\?cmd=savecsv/) {
			my $li = $q->param('li');
			$li = 'main' if 'tl' eq $li;
			my $net;
			if($main{$li}) {
				$net = do_save_export_csv($hr{$li});
			} else {
				$net = do_save_csv($li);
			}
			if($net) {
				$c->hc_send_file_attach($net,'HistCite CSV file.csv');
				unlink $net;
			} else {
				$c->send_response(new HTTP::Response(200,'OK',$h,"There was a problem creating a temporary file.  See log for details.  <a href=javascript:history.go(-1)>OK</a>"));
			}

		} elsif ($r->url =~ /\?cmd=viewlog/) {
			$c->send_response(new HTTP::Response(200,'OK',$h,${view_log()}));
		} elsif ($r->url =~ /\?cmd=viewdup/) {
			$c->send_response(new HTTP::Response(200,'OK',$h,${view_log('dup')}));

		} elsif ($r->url =~ /properties/) {
			if($r->url =~ /action=Apply/) {
				props_set($q);
				$c->send_response(new HTTP::Response(200,'OK',$h,"<script>opener.location.replace(opener.location.pathname + '?${\(time)}');close()</script>"));
			} else {
				$c->send_response(new HTTP::Response(200,'OK',$h,view_properties()));
			}

		} elsif ($r->url =~ /settings\/?(\w*)/) {
			my $set = $1;
			if($q and $q->param('actin')) {
				s_sets_set($q, $set);
				$c->send_response(new HTTP::Response(200,'OK',$h,"<script>opener.location.replace(opener.location.pathname + '?${\(time)}');close()</script>"));
			} else {
				s_html_init() if $q and $q->param('htmldefaults');
				s_sets_init() if $q and $q->param('defaults');
				$c->send_response(new HTTP::Response(200,'OK',$h,view_settings($set)));
			}

		} elsif ($r->url =~ /\?help=(\w*)\.html/) {
			system(qq(start hh "$HistCiteHome/histcite.chm::/$1.html"));
			$c->send_response(new HTTP::Response(200,'OK',$h,'ok'));

		} elsif ($r->url =~ /help\/?(\w*)\.html/) {
				$c->send_response(new HTTP::Response(200,'OK',$h,help($1)));

		} elsif ($r->url =~ /\?cmd=close/) {
			full_reset();
			$c->send_redirect("http://$host:$port/", 302);

		} elsif ($r->url =~ /\?cmd=exit/) {
			#++$TheTip;
			print LOG save_conf(), "\n";
			if($ie) {
				$ie->Quit;
			} else {
				$c->send_response(new HTTP::Response(200,'OK',$h,'<script>window.close()</script>The session is over.'));
				if($pf) {
					my @ps = `ps x|grep '\\$pf'`;
					my ($pid) = split ' ', $ps[0], 2;
					kill 9, $pid if $pid =~ /^\d+$/;
				}
			}
			if(-e $dup_file) {
				unlink $dup_file if 0 == -s $dup_file;
			}
			my $diff = time() - $^T;
			my $st = s2h($diff);
			print LOG "The session lasted $diff secs ($st)\n", scalar localtime, "\n";
			print "The session lasted $diff secs ($st).\n";
			exit;

		} elsif ('/' eq $path or $path =~ m!^/((mark|temp)/)?index!) {
			$temp_what = '';	#used in or only for now
			my $ismark = $1;
			my $ent = $ismark ? $2 : 'main';
			my($what, $page, $index);
			$index = $path;
			$index =~ s/\.html$//;
			(undef, $what, $page) = split /-/, $index;
			if(defined $what and $what =~ /^\d/) {
				$page = $what;
				$what = $PAGER{$ent}||'tl';
			}
			$what ||= $PAGER{$ent}||'tl';
			$page ||= 1;
			my $item = ($page - 1) * $MAIN_PI;
			my($found, $advance);
			($what, $item, $found, $advance )
				= do_temp_query($q, $ent, $what, $item, $c, $path) if $q;
			next unless $what;	#0 client has been served
			$what = 'tl' if 'py' eq $what;	#pub date is default now
			if('main' ne $ent) {
				list_tots($ent);
			}
			if($ent eq 'mark') {
				$c->send_response(new HTTP::Response(200,'OK',$h,
					${mark2html($what, $item, $advance, $found)}));
			} elsif($ent eq 'temp') {
				my @t = keys %{$hrt};
				my $recs = @t;
				if($recs or $m_search_form_show) {
					$c->send_response(new HTTP::Response(200,'OK',$h,
						${temp2html($what, $item, $advance, $found)}));
				} else {
					$c->send_redirect("http://$host:$port/", 302);
				}
			} else {
				$c->send_response(new HTTP::Response(200,'OK',$h,
					${main2html($what, 0, $item, $advance, $found)} ));
			}

		} elsif ('/customize' eq $path) {
			$c->send_redirect("http://$host:$port/", 302) unless $NODES;
			if($q and defined $q->param('customize')) {
				cust_form($q);
				$VIEW = 'cust';
				$c->send_redirect("http://$host:$port/", 302);
				$customize1 = 0;
			} elsif($q and defined $q->param('cancel')) {
				my $url = $last_url ? $last_url : "http://$host:$port/";
				$c->send_redirect($url, 302);
				$customize1 = 0;
			} else {
				$last_url = $r->referer() unless $customize1;
				++$customize1;
				my $what ||= $PAGER{main}||'tl';
				$c->send_response(new HTTP::Response(200,'OK',$h,
					${customize($what)} ));
			}

		} elsif ('/search/' eq $path) {
			%{$hrt} = (); @{$pager{temp}} = ();
			$temp_title = 'Search'; $temp_term = $temp_head = '';
			$m_search_form_show = 1;
			$c->send_redirect("http://$host:$port/temp/index-tl.html", 302);

		} elsif ('/searchmarks/' eq $path) {
			%{$hrt} = %{$hrm}; @{$pager{temp}} = ();
			$temp_title = 'Search marks'; $temp_term = ''; $temp_head = 'marked';
			$m_search_form_show = 1;
			$c->send_redirect("http://$host:$port/temp/index-tl.html", 302);

		} elsif ($path =~ /\/list\/(ml|or|au|so|wd|tg|dt|py|la|in|i2|co)-?(\w*)-?(\d*)\.html/) {
			my $page = '' ne $3 ? $3 : 1;
			my $what = $2||$PAGER{$1}||'none';
			my($found, $advance) = (1,0);
			if('or' eq $1) {
				my %cays = qw(ca 1 cy 1 so 1);
				or_prep() if($cays{$what} and $needprep_or);
			}
			my $item = $page * $AU_PI - $AU_PI;	#no page index in ml|or
			if($q) {
				if($q->param('actin') or $q->param('tagset')) {
					if($q->param('actin') and 'Delete' eq $q->param('actin')) {
						$c->hc_send_cont_head();
						print $c $hi_msie, "<title>HistCite: Deleting..</title>Deleting records..<br><pre>";
						mark_main_form($q, $1, $what, $page, $c); 
						print $c "</pre><script>location.href='$path?${\(time)}'</script><a href=/>OK</a>";
						next;
					} else {
						mark_main_form($q, $1, $what, $page); 
					}
				} elsif($q->param('editnow')) {
					$m_defer_net = $q->param('defer_net') ? 1 : 0;
					if($m_defer_net) {
						edit_form($q, $1);
					} else {
						$c->hc_send_cont_head();
						print $c $hi_msie, "<title>HistCite: Editing..</title>Editing records..<br><pre>";
						edit_form($q, $1, $c);
						print $c "</pre><script>location.href='$path?${\(time)}'</script><a href=/>OK</a>";
						next;
					}
				}
				if($q->param('advance') and 'next' eq $q->param('advance')) {
					$advance = 'next';
					$item = $q->param('item');
				}
				if(($q->param('advance') and 'next' ne $q->param('advance'))
					or $q->param('moveto') and 'Go' eq $q->param('moveto')) {
					($what, $item, $found) = goto_main_form($q, $1);
					$advance = 1;
				}
			}
			$list_span = '';
			if('or' eq $1) {
				$c->send_response(new HTTP::Response(200,'OK',$h,
					${outs2html($what, '', $item, $advance, $found)} ));
			} elsif('ml' eq $1) {
				$c->send_response(new HTTP::Response(200,'OK',$h,
					${ml2html($what, '', $item, $advance, $found)} ));
			} else {
				$c->send_response(new HTTP::Response(200,'OK',$h,
					${ausos2html($1,$what,0,$item, $advance, $found)} ));
			}
			$customize1 = 0;

		} elsif ($path =~ /update_modules/) {
			$c->hc_send_cont_head();
			print $c $hi_msie, '<pre>';
			do_timeline_and_network($c) if $NET_DIRTY;
			do_modules(undef, $c);
			my $path = "http://$host:$port";
			print $c qq(</pre><script>location.href="$path"</script><a href="$path">OK</a>);

		} elsif ($path =~ /\/node\/(\d+)\.html/) {
			$c->send_response(new HTTP::Response(200,'OK',$h,${node2html($tl[$1])}));

		} elsif ($path =~ /\/node\/dump-(\d+)*\.html/) {
			$c->send_response(new HTTP::Response(200,'OK',$h,node2dump($tl[$1])));

		} elsif ($path =~ /\/node\/edit-(\d+)*\.html/) {
			my $cri = $q->param('i') if $q;
			$c->send_response(new HTTP::Response(200,'OK',$h,
				${edit_node2html($1, $cri)}));

		} elsif ($path =~ /\/node\/edit_node$/) {
			$c->send_response(new HTTP::Response(200,'OK',$h,${edit_node($q)}));

		} elsif ($path =~ m!/(citers|citees)/(\d+)/(index.*)?!) {
			my $loc = ('citers' eq $1 ? 'cited' : 'cites');
			my $n = $2;
			my $citeid = "$loc$n";
			$temp_what = $temp_term = '';
			$temp_title = brief_citation($n);
			$temp_head = ('cited' eq $loc ? 'citing ' : 'cited by ');
			$temp_head .= ${citation2html($n)};
			my($what,$page,$index,$found, $advance);
			$index = $3;
			if($index) {
				$index =~ s/\.html$//;
				(undef, $what, $page) = split /-/, $index;
				if(defined $what and $what =~ /^\d/) {
					$page = $what;
					$what = $PAGER{$ent}||'tl';
				}
				$what ||= $PAGER{$ent}||'tl';
				$page ||= 1;
			} else {
				$what = 'tl'; $page = 1;
			}
			my $item = ($page - 1) * $MAIN_PI;
			if($q) {
				($what, $item, $found, $advance )
					= do_temp_query($q, 'temp', $what, $item, $c, $path);
			} else {
				%{$hrt} = (); @{$pager{temp}} = ();
				for my $a (@{$hra->{$tl[$n]}->{$loc}}) { $hrt->{$tl[$a]} = 1 }
			}
			next unless $what;	#0 client has been served
			if($temp_head eq 'found') {
				$c->send_redirect("http://$host:$port/temp/index-tl.html", 302);
			} else {
				list_tots('temp', $citeid);
				$c->send_response(new HTTP::Response(200,'OK',$h,
					${temp2html($what, $item, $advance, $found)}));
			}

		} elsif ($path =~ m!/(au|so|wd|tg|py|dt|la|co|in|i2|ml|or)/(\d+)/(index.*)?!) {
			my($hr,$item);
			$hr = $hr{$1}; $item = $ari{$1}->[$2];
			$temp_what = $1;
			$temp_item = $item;
			my $ent = $1;
			my $entid = "$1$2";
			my($pref,$pref2) = ('');
			if('ml' eq $ent or 'or' eq $ent) {
				$temp_term = $hr->{$item}->{cr};
				$pref2 = 'citing ';
			} else {
				$temp_term = $hr->{$item}->{name};
				$pref = "$f_ful{$ent}: ";
				$pref2 = "for $f_ful{$ent} ";
			}
			if('tg' eq $1) {
				if($temp_term) {
					$temp_term = "$item: $temp_term"
				} else {
					$temp_term = $item
				}
			}
			$temp_title = "$pref$temp_term";
			$temp_head = "$pref2<b>$temp_term</b>";
			my($what,$page,$index,$found, $advance);
			$index = $path; #$3;
			$index =~ s/\.html$//;
			(undef, $what, $page) = split /-/, $index;
			if(defined $what and $what =~ /^\d/) {
				$page = $what;
				$what = $PAGER{temp}||'tl';
			}
			$what ||= $PAGER{temp}||'tl';
			$page ||= 1;
			my $page_item = ($page - 1) * $MAIN_PI;
			if($q) {
				($what, $page_item, $found, $advance )
					= do_temp_query($q, 'temp', $what, $page_item, $c, $path);
			} else {
				##NEED OPTIMIZE
				%{$hrt} = (); @{$pager{temp}} = ();
				for my $a (eval $hr->{$item}->{nodes}) { $hrt->{$tl[$a]} = 1 }
			}
			next unless $what;	#0 client has been served
			if($temp_head eq 'found') {
				$c->send_redirect("http://$host:$port/temp/index-tl.html", 302);
			} else {
				list_tots('temp', $entid);
				$c->send_response(new HTTP::Response(200,'OK',$h,
					${temp2html($what, $page_item, $advance, $found)}));
			}

		} elsif ($path =~ /\/graph\/list\.html/) {
			my @g = ();
			@g = $q->param('graph') if defined $q;
			for my $g (@g) {
				for my $n (eval $g{$g}->{nodel}) {
					--$on_kept_graph{$n};
				}
				delete $g{$g} if exists $g{$g};
			}
			$c->send_response(new HTTP::Response(200,'OK',$h,graph_list()));

		} elsif ($r->url =~ /\/graph\/(\d+).html$/) {
			$c->send_response(new HTTP::Response(200,'OK',$h,g2html($g{$1}, $1, 0)));

		} elsif ($r->url =~ /\/glossary\.html$/) {
			$c->send_response(new HTTP::Response(200,'OK',$h,$$glossary.$esclose));
		} elsif ($r->url =~ /\/about\.html$/) {
			$c->send_response(new HTTP::Response(200,'OK',$h,$$about.$esclose));

		}#elsif ($r->url =~ /\/tip\.txt\?next=(-?\d)$/) {
			#my $next = $1;
			#$c->send_response(new HTTP::Response(200,'OK',$h,get_tip($next)));

		#} elsif ($r->url =~ /\/tipStart\?on=(\d)$/) {
			#$TipOnStart = $1;
			#$c->send_response(new HTTP::Response(200,'OK',$h,''));

		#} 
		elsif($path =~ m!/(\w*.(gif|png))$!) {
			my $img = $PerlApp::VERSION ? "$INC[0]$1" : "img/$1";	#'bit hacky
			$c->send_file_response($img);
		} elsif($path =~ /csshover2.htc$/) {
			my $htc = $PerlApp::VERSION ? "$INC[0]csshover2.htc" : 'csshover2.htc';
			$c->send_file_response($htc);
		} elsif($path =~ /favicon.ico$/) {
			$c->send_response(new HTTP::Response(404,'OK'));
		} else {
			$c->send_response(new HTTP::Response(200,'OK',$h,"invalid request with: $path"));
		}
		$c->force_last_request();
		#print "\t\tdone with the response.?.\n";
#		last if 3 > (time() - $client_time);
	}
	#print "\tClient timeout? ", time() - $client_time, "\n";
}

exit;

sub do_temp_query {
	my($q, $ent, $what, $item, $c, $path) = @_;
	if($q->param('actin') or $q->param('tagset')) {
		if($q->param('actin') and 'Delete' eq $q->param('actin')) {
			$c->hc_send_cont_head();
			print $c $hi_msie, "<title>HistCite: Deleting..</title>Deleting records..<br><pre>";
			mark_main_form($q, $ent, $what, $item, $c); 
			print $c "</pre><script>location.href='$path?${\(time)}'</script><a href=/>OK</a>";
			return 0;
		} else {
			mark_main_form($q, $ent, $what, $item); 
		}
	} elsif($q->param('search')) {
		%$hrt = () if 'Search collection' eq $q->param('search');
		search_form($q);
		@{$pager{temp}} = ();
		$temp_title = 'Search results';
		$temp_head = 'found';
		$temp_term = '';
	}
	if($q->param('advance') and 'next' eq $q->param('advance')) {
		$advance = 'next';
		$item = $q->param('item');
	}
	if(($q->param('advance') and 'next' ne $q->param('advance'))
		or $q->param('moveto') and 'Go' eq $q->param('moveto')) {
		($what, $item, $found) = goto_main_form($q, $ent);
		$advance = 1;
	}
	return ($what, $item, $found, $advance);
}

sub list_tots {
	my $ent = shift;
	my $entid = shift||'';
	my $hr = $hr{$ent};
	my($ymin,$ymax) = (3000,0);
	$list_lcs = $list_lcsx = $list_gcs = $list_scs = $list_gcs_num = $list_scs_num = $list_na = $list_ncr = 0;

	while(my ($rid,$v) = each %$hr) {
		my $p = $hra->{$rid};
		$list_lcs += $p->{lcs};
		$list_lcsx += $p->{lcsx};
		if($p->{tc} > -1) {
			$list_gcs += $p->{tc};
			++$list_gcs_num;
		}
		if($p->{scs} > -1) {
			$list_scs += $p->{scs};
			++$list_scs_num;
		}
		$list_na += $p->{na};
		$list_ncr += $p->{ncr};
		$ymin = $p->{py} if $p->{py} < $ymin;
		$ymax = $p->{py} if $p->{py} > $ymax;
	}
	$list_span = $ymax ? "List span: $ymin - $ymax" : '';
	if('base' ne $VIEW && $ymax) {
		$list_span .= " (". ($ymax - $ymin + 1) ." years)";
	}
	$list_hindex = list_stats($ent, $entid);
}

sub list_stats {
	my($ent,$entid) = @_;
	my $hr = $hr{$ent};
	my @hi;
	my %show = qw(lcs HIL_SHOW lcsx HIX_SHOW tc HIG_SHOW scs HIS_SHOW);
	my $entkey = $entid||$ent;
	for my $fi qw(lcs lcsx tc scs) {
		if(eval("\$$show{$fi}") or 'bibl' eq $VIEW) {
			next if exists $stats{$entkey}{hindex}{$fi} && !$DIRTY;
			my @i = $sorted_by{$fi}->($hr);
			if('tc' eq $fi && $hra->{$i[0]}->{tc} < 0) {
				$stats{$entkey}{hindex}{tc} = 'n/a';
				next;
			}
			my $hi = 0;
			for my $i (@i) {
				last if $hi >= $hra->{$i}->{$fi};
				++$hi if $hra->{$i}->{$fi} >= ($hi + 1);
			}
			$stats{$entkey}{hindex}{$fi} = $hi;
		} else {
			delete $stats{$entkey}{hindex}{$fi};
		}
	} continue {
		push @hi, "h-index ($f{$fi}) $stats{$entkey}{hindex}{$fi}"
			if exists $stats{$entkey}{hindex}{$fi};
	}
	return join ', ', @hi;
}

sub get_median {
	my($ent,$what) = @_;
	my $ar = $pager{$ent};
	my($q1, $m, $q3, $n);
	my $N = @{$ar};
	$n = $N;
	my @pa = ();
	if('tc' eq $what or 'scs' eq $what) {
		$n = 0;
		for my $id (@{$ar}) {
			if($hra->{$id}->{$what} > -1) {
				++$n;
				push @pa, $id;
			}
		}
		$ar = \@pa if $N > $n;
	}
	use integer;
	if(5 > $n) {
		$q1 = $m = $q3 = 'n/a';
	} elsif(1 == ($n % 2)) {
		my $n2 = $n / 2;
		$m = $hra->{$ar->[$n2]}->{$what};
		($q1, $q3) = _calc_q1_q3($ar, $what, $n2, 1);
	} elsif(0 == ($n % 2)) {
		my $i1 = $n / 2;
		my $i0 = $i1 - 1;
		do {
			no integer;
			$m = ($hra->{$ar->[$i0]}->{$what} + $hra->{$ar->[$i1]}->{$what}) / 2;
		};
		($q1, $q3) = _calc_q1_q3($ar, $what, $i1, 0);
	}
	# FIX THIS NEXT - what to fix?
	$stats{"$ent$what"} = "$f{$what} Quartiles: Q1 $q1, Me $m, Q3 $q3"
		if 'main' eq $ent;
	return ($q1, $m, $q3, $n, $N);
}

sub _calc_q1_q3 {
	my($ar, $what, $n2, $odd) = @_;
	my($n4th, $q1, $q3);
	use integer;
	if(1 == ($n2 % 2)) {
		$n4th = $n2 / 2;
		$q1 = $hra->{$ar->[$n4th]}->{$what};
		$q3 = $hra->{$ar->[$n2+$n4th+$odd]}->{$what};
	} else {
		my $i1 = $n2 / 2;
		my $i0 = $i1 - 1;
		$n2 += $odd;
		do {
			no integer;
			$q1 = ($hra->{$ar->[$i0]}->{$what} + $hra->{$ar->[$i1]}->{$what}) / 2;
			$q3 = ($hra->{$ar->[$n2+$i0]}->{$what} + $hra->{$ar->[$n2+$i1]}->{$what}) / 2;
		};
	}
	no integer;
	($q1, $q3) = ($q3, $q1) if $q1 > $q3;

	return ($q1, $q3);
}

sub get_cmd_args {
	$AB_ON = 1;
	$CR_ON = 1;
while(my $s = shift) {
	if($s =~ /^-cr$/i) {
		$DO_OR = 0;
	} elsif($s =~ /^-ml$/i) {
		$DO_ML = 0;
	} elsif($s =~ /^-wd$/i) {
		$DO_WD = 0;
	} elsif($s =~ /^-ab$/i) {
		$AB_ON = 0;
	} elsif($s =~ /^-cr$/i) {
		$CR_ON = 0;
	} elsif($s =~ /^-ti$/i) {
		my $i = shift||'';
		if($i =~ /^\d+$/) {
			$MAIN_TI = $i;
		} else {
			unshift @ARGV, $i;
		}
	} elsif($s =~ /^-pi$/i) {
		my $i = shift||'';
		if($i =~ /^\d+$/) {
			$MAIN_PI = $i;
		} else {
			unshift @ARGV, $i;
		}
	} elsif($s =~ /^--full-cited-author$/i) {
		$FULL_CA = 1;
	} elsif($s =~ /^--with-browser$/i) {
		$browser = shift;
	} elsif($s =~ /^--localhost-as-name$/i) {
		$HOST_AS_NAME = 1;
	} elsif($s =~ /^-t$/i) {
		$s = shift||'';
		$$title_line = $s;
	} elsif($s =~ /^--detail/i) {
		$DETAIL = 1;
	} else {
		if ('MSWin32' eq $^O) {
			push @cmd_file, glob $s;
		} else {
			push @cmd_file, $s;
		}
	}
}
}

sub create_logs {
	$log = "$LogPath/HistCiteLog.htm";
	open LOG, ">$log" or do {
		my_error(\"Cannot create log file '$log':\n$!", '', 'nolog');
		exit;
	};
	open STDERR, ">&=LOG";
print LOG "<pre>";
	print LOG scalar localtime, "\nHistCite $$VERSION\n\n";
	print LOG 'Log (this) file: ', realpath($log), "\n";
	print LOG "$host:$port\n";
	print LOG join(' ', uname()), "\n";
	print LOG "$LogWarn\n" if $LogWarn;
	LOG->autoflush(1);
	STDERR->autoflush(1);

	$dup_file = "$LogPath/HistCiteDups.htm";
	open DUP, ">$dup_file" or do {
		print LOG "Cannot set log file for duplicates '$dup_file': $!\n";
	};
	close DUP;
}

sub test_temp {
	print LOG "Temp location: $TmpPath";
	my $tf = "$TmpPath/test" . time();
	if(open F, ">$tf") {
		close F; unlink $tf;
	} else {
		my_error(\"Temporary location '$TmpPath' not available:\n$!\n\nYou may run into problems later.", '', 'nolog');
		print LOG ": <font color=red>$!</font>";
	}
	print LOG "\n";
}

sub another_session_runs {
	if(-e $PortFile) {
		if(open RUN, "$PortFile") {
			$port = <RUN>; close RUN;
			if($port =~ /^\d+$/) {
				use LWP::UserAgent;
				my $ua = LWP::UserAgent->new;
				$ua->timeout(3);
				my $req = HTTP::Request->new(GET => "http://$host:$port/alive");
				my $res = $ua->request($req);
				if($res->is_success) {
					my_error(\"Another instance of HistCite is running!\n\nTrying to attach to the existing session.", 'HistCite Alert', 'nolog');
					return 1;
				} else {
					#must be a stale run handle; HistCite long gone
				}
			} else {
				#discard invalid input
			}
		}
	}
	return 0;
}

sub start_daemon {
	while(not defined $daemon) {
		++$port;
		$daemon = new HC::HTTP::Daemon LocalAddr => $host, LocalPort => $port;
		last if $port > 2924;
	}
	if(not defined $daemon) {
		$daemon = new HC::HTTP::Daemon LocalAddr => $host;
	}
	if(not defined $daemon) {
		my_error(\"Cannot obtain local TCP/IP port!\n\nFatal error.");
		exit;
	}
	$port = $daemon->sockport();
	return $port;
}

sub start_browser {
	my($browser, $start_path) = @_;
	if('MSWin32' eq $^O) {
		$browser = ($browser ? qq("$browser") : '');
		use Win32::OLE;
		use Win32;
		$Win32::OLE::Warn = $Win32::OLE::Warn = 0;
		if($browser) {
			system(qq(start "" $browser $start_path));
		} elsif($ie = Win32::OLE->new('InternetExplorer.Application')) {
			$ie->{Toolbar} = 0;
			$ie->{Visible} = 1;
			$ie->Navigate($start_path);
			$IE6 = 1 if $ie->{Name} =~ /Microsoft/;
			$IE7 = 1 if $ie->{Name} =~ /Windows/;
		} else {
			print LOG "\nFailed to create MSIE object.\n";
			system(qq(start $start_path));
		}
		$unix_bg = '';
	} else {
		$browser ||= 'firefox';
		$pf = ($browser =~ /firefox$/) ? '-P hici' : '';
		system("\"$browser\" $pf $start_path &");
		$unix_bg = '&';
	}
}

sub read_batch {
	my($fr, $FH) = @_;
	if($FH) {
		my $o = "$STD<HEAD><TITLE>HistCite - Loading File...</TITLE></HEAD>";
		add_body_style_main(\$o);
		add_live_menu(\$o, 'tl');
		$o .= '<br id="menu_pm" class="nonprn">';
		$o .= "<SCRIPT>var men = document.getElementById('menu');men.style.display='none';</SCRIPT><pre class=ui>";
		print $FH $o;
	}

	my $read1 = 0;
	my $err1 = 0;
	for my $f (@{$fr}) {
		my($r, $err) = read_file($f, 250, $FH);
		$NEEDSAVE = 1 if @file;
		push @file, $f if $r;
		$read1 = ($read1 ? $read1 : $r);
		$err1 = ($err1 ? $err1 : $err);
	}
	if($read1) {	#do iff read at least 1
		my $T = time;
		do_timeline_and_network($FH);
		for my $m (@all_mod) { $dirty{$m} = 1 };
		do_modules(undef, $FH);
		print_ln($FH, \"All steps --");
		do_done($T, $FH);
		$DIRTY_CHARTS = 1;
		$title_file ||= $FILENOW ? basename($FILENOW) : basename($file[0]);
		$$title = $title_file;
	}

	print $FH "</pre><script>location.href='/'</script><a href=/>OK</a>"
		if $FH and not $err1;
	return ! $err1;
}

sub do_timeline_and_network {
	my $FH = shift;
	print_ln($FH, \"\nIndexing records.. ");
	my $t = time();
	do_timeline();
	get_span();
	do_done($t, $FH);
	print_ln($FH, \("\t<b>Records: ". @tl ."</b>\n"
		. "\t<b>Collection span: $net_first_year - $net_last_year</b>\n"));

	do_network(1000, $FH);
	$NET_DIRTY = 0;
	$TL_MODIFIED = 1;

	calc_totals();
	calc_over_t();
	calc_lcs_cuts();
}

sub get_span {
	$net_last_year = 0;
	do { my @t = localtime; $net_first_year = 1900 + $t[5] };
	for my $id (keys %{$hra}) {
		$net_last_year = $hra->{$id}->{py} if $hra->{$id}->{py}> $net_last_year;
		$net_first_year = $hra->{$id}->{py} if $hra->{$id}->{py} < $net_first_year;
	}
}

sub print_ln {	#print to LOG and FH if set
	my $FH = shift;
	my $sr = shift;
	my @fh = (LOG); push @fh, $FH if $FH;
	for my $fh (@fh) {
		print $fh $$sr;
	}
}

sub do_modules {
	my $optional = shift;
	my $FH = shift;
	my($t, $T, $done);
	$T = time;
	$done = 0;
	$mod{au} = {'name', 'All-Author list', 'code', \&do_authors, 'p', 'a'};
	$mod{so} = {'name', 'Journal list', 'code', \&do_journals, 'p', 's'};
	$mod{wd} = {'name', 'Word (in '. inf_wd(1) .') list', 'code', \&do_wd, 'p', 'w'};
	$mod{tg} = {'name', 'Tag list', 'code', \&do_tags, 'p', 'ta'};
	$mod{or} = {'name', 'Cited References', 'code', \&do_outer, 'p', 'o'};
	$mod{ml} = {'name', 'Missing links', 'code', \&do_missed, 'p', 'm'};
	$mod{py} = {'name', 'Publication year list', 'code', \&do_list, 'p', 'y'};
	$mod{dt} = {'name', 'Document type list', 'code', \&do_list, 'p', 'dt'};
	$mod{la} = {'name', 'Language list', 'code', \&do_list, 'p', 'la'};
	$mod{co} = {'name', 'Country list', 'code', \&do_list, 'p', 'co'};
	$mod{in} = {'name', 'Institution list', 'code', \&do_list, 'p', 'in'};
	$mod{i2} = {'name', 'Institution with Subdividion list', 'code', \&do_list, 'p', 'i2'};

	$mod{au}{DO} = $mod{so}{DO} = ! $optional;
	$mod{au}{DO_OLD} = $mod{so}{DO_OLD} = 0;
	for my $mo qw(wd tg or ml) {
		my $MO = uc $mo;
		$mod{$mo}{DO} = eval "\$DO_$MO";
		$mod{$mo}{DO_OLD} = eval "\$DO_${MO}_OLD";
	}
	for my $f qw(py dt la co in i2) {
		$mod{$f}{DO} = 1;
	}

	for my $ent qw(au so wd py dt la co in i2 tg or ml) {
		next unless ($mod{$ent}{DO} and not $mod{$ent}{DO_OLD});
		next unless $dirty{$ent};
		print_ln($FH, \"Processing $mod{$ent}{name}..");
		print $mod{$ent}{p};
		$t = time();
		my $rs = $mod{$ent}{code}($FH, $ent);
		do_done($t, $FH);
		++$done;
		print_ln $FH, \"\t<b>$rs</b>\n";
		@{ $pager{$ent} } = ();
		$dirty{$ent} = 0;
	}

	if(0 < $done) {
		$DIRTY = 0;
		%stats = ();
		$TL_MODIFIED = 0;
		print_ln($FH, \'All modules:');
		do_done($T, $FH);
	}
}

sub inf_wd {
	my $ext = shift;
	my @w = ();
	if($DO_USE_WD_TI) {
		my $w = 'Titles';
		if($ext) {
			$w .= ' (';
			$w .= $DO_USE_STOPWD ? 'stopwords' : '';
			$w .= $SMALL_WORD ? " $SMALL_WORD" : '';
			$w .= $DO_SPLIT_DASH ? ' split-hyphen' : ' keep-hyphen';
			$w .= ')';
		}
		push @w, $w;
	}
	if($ON_DE && $DO_USE_WD_DE) {
		push @w, 'Author keywords';
	}
	if($ON_ID && $DO_USE_WD_ID) {
		push @w, 'KeyWords+';
	}
	if($ON_DE && $DO_USE_WD_DE or ($ON_ID && $DO_USE_WD_ID) ) {
		my $w = ' [';
		$w .= $DO_KEY_SPLIT_WORDS ? 'single keywords' : 'keep keyterms';
		$w .= $DO_KEY_SPLIT_DASH ? ' split-hyphen' : ' keep-hyphen';
		$w .= ' ]';
		push @w, $w;
	}
	my $o = @w ? join ', ', @w : 'no words included';
	return $o;
}

sub do_save_html_estimate {
	my $total = 0;
	my $sep = ' -"- ';

	my $o = <<"";
<body vlink=blue onLoad="focus()">
<STYLE>body { font: 10pt Verdana; background: $BG_COLOR; }
a { text-decoration: none; }
a:hover { text-decoration: underline; color: blue; }</STYLE>
<div><b>HTML presentation estimate</b></div><p>
The HTML Export option allows the user to export a complete data collection with related analyses and graphs as a set of HTML documents suitable for display on a web site, or on another computer where the HistCite program is not installed.
<p>
	The program can generate every possible screen as a separate HTML file. Depending on the size of the collection, this can result in a very large number of files. The information below shows the number of files that will be generated, based on the parameters chosen in the HTML Presentation 
<a href=# OnClick=\"window.open('/settings/html','settings','width=480,height=480,resizable=yes,scrollbars=yes,status=yes')\">Settings</a>.</p>

	# "Printing the network linearly.. ";
	for my $id (@tl) {
		my $pub = $hra->{$id};
		++$total if (!$HTML_LIMITS or $on_kept_graph{$pub->{tl}}
			or ($pub->{lcs} >= $HTML_LCS or $pub->{tc} >= $HTML_GCS));
	}
	$o .= "$total <b>files for</b> records";
	if($HTML_LIMITS) {
		$o .= " with LCS >= $HTML_LCS, or GCS >= $HTML_GCS";
		$o .= ", or selected for historiographs" if scalar keys %g;
	}
	my $cited = 0; my $cites = 0;
	for my $rid (@tl) {
		++$cited if (!$HTML_LIMITS && 1<$hra->{$rid}->{lcs}
			or $HTMLPUBS < $hra->{$rid}->{lcs});
		++$cites if (!$HTML_LIMITS && 1<$hra->{$rid}->{lcr}
			or $HTMLPUBS < $hra->{$rid}->{lcr});
	}
	$total += $cited + $cites;
	$o .= "<br>$cited $sep list of citing records for each record";
	$o .= " with LCS &gt; $HTMLPUBS" if $HTML_LIMITS;
	$o .= "<br>$cites $sep list of cited records for each record";
	$o .= " with LCR &gt; $HTMLPUBS" if $HTML_LIMITS;
	do {
		use integer;
		my $pages = ($#tl + 1) / $MAIN_PI;
		++$pages if ($#tl + 1) % $MAIN_PI;
		local $HTMLPAGE = $HTML_LIMITS ? $HTMLPAGE : $pages;
		$HTMLPAGE = $pages if $HTMLPAGE > $pages;
		$pages = $HTMLPAGE if $HTML_TL2;
		$o .= "<p>$pages $sep date sorted page of the main table";
		$o .= " (${\($HTML_TL2 ? 'limit '.$HTMLPAGE : 'no limit')})" if $HTML_LIMITS;
		$total += $pages;
		my $cols = 0;
		for my $f (keys %{ $view{main}{$VIEW} }) {
			next if 'tl' eq $f or 'gcs' eq $f;
			next if !$view{main}{$VIEW}{$f};
			++$cols;
		}
		my $n = $HTMLPAGE * $cols;
		$o .= "<br>$n $sep other sorted page of the main table";
		$o .= " (limit $HTMLPAGE per sorted field)" if $HTML_LIMITS;
		$total += $n;
	};

	for my $ent qw(au so wd tg py dt la in i2 co) {
		my $t = $mod{$ent}{name};
		my $ar = $ari{$ent};
		next if 'wd' eq $ent and not $DO_WD;
		next if 'tg' eq $ent and not $DO_TG;
		# "Printing $t list..";
		do {
			use integer;
			my $pages = ($#$ar + 1) / $AU_PI;
			++$pages if ($#$ar + 1) % $AU_PI;
			local $HTMLPAGE = $HTML_LIMITS ? $HTMLPAGE : $pages;
			$HTMLPAGE = $pages if $HTMLPAGE > $pages;
			$pages = $HTMLPAGE if $HTML_TL2;
			$o .= "<p>$pages $sep alphabetical sorted page of $t";
			$o .= " (${\($HTML_TL2 ? 'limit '.$HTMLPAGE : 'no limit')})" if $HTML_LIMITS;
			$total += $pages;
			my $cols = 0;
			for my $fi (keys %{$view{$ent}{$VIEW}}) {
				next if 'name' eq $fi or 'perc' eq $fi;
				next if !$view{$ent}{$VIEW}{$fi};
				++$cols;
			}
			my $n = $HTMLPAGE * $cols;
			$o .= "<br>$n $sep other sorted page of $t";
			$o .= " (limit $HTMLPAGE per sorted field)" if $HTML_LIMITS;
			$total += $n;
			my $cited = 0;
			for my $k (keys %{$hr{$ent}}) {
				++$cited if !$HTML_LIMITS && 1<$hr{$ent}->{$k}->{pubs}
					or $HTMLPUBS < $hr{$ent}->{$k}->{pubs};
			}
			$o .= "<br>$cited $sep list of records for each item";
			$o .= " with number of records &gt; $HTMLPUBS" if $HTML_LIMITS;
			$total += $cited;
		};
	}

	if($DO_OR) {
		# "Printing Outer References.. ";
		$o .= "<p>4 $sep sorted page of Cited References List<br>\n";
		$total += 4;
		my $cited = 0;
		my $i = 0;
		for my $ci ($ausos_by->('pubs', \%or)) {
			++$cited if !$HTML_LIMITS && 1<$or{$ci}->{pubs}
				or $HTMLPUBS < $or{$ci}->{pubs};
			++$i; last if $i == $AU_PI;
		}
		$o .= "$cited $sep list of citing records for each Cited Reference";
		$o .= " with LCS &gt; $HTMLPUBS" if $HTML_LIMITS;
		$total += $cited;
	}

	# "Printing Histograms..";
	$o .= "<p>1 list of graphs<br>\n";
	++$total;
	do_prepare_histograms();
	my @fi = ();
	$cited = 0;
	for $k (keys %higram) {
		if($higram{$k}->{enabled}) {
			push @fi, $k;
			my $hr = \%{$higram{$k}->{item}};
			if('pyX' eq $k) {
				if($higram{'py'}->{enabled}) {
					next;
				} else {
					$hr = \%{$higram{'py'}->{item}};
				}
			}
		}
	}
	if(@fi) {
		$o .= scalar @fi ." $sep histogram<br>\n";
		$total += @fi;
	}

	my $g = (keys %g);
	my $n = 3 * $g;
	$o .= 3 * $g ." $sep $g Historiographs<br>\n" if $g;
	$total += $n;

	#glossary.html about.html index.html
	#for $h qw(stopwords wd co)
	$o .= "<p>6 help and other files<br>\n";
	$total += 6;

	$o .= <<"";
<p>Total: $total files.
<p>This will take time to generate, and will consume extra storage.
Performance of your computer for other tasks during this time may be degraded.
<p><a href='/savehtml' target=_new>Proceed</a>
&nbsp; &nbsp;
<a href=# OnClick=\"window.open('/settings/html','settings','width=480,height=480,resizable=yes,scrollbars=yes,status=yes')\">Settings</a>
&nbsp; &nbsp;
<a href="javascript:close()">Cancel</a></body>

	return $o.$esclose;
}

sub do_save_html {
	my $T = time;
	my $err = shift;
	local $LIVE = 0;
	local %PAGER = %PAGER;
	local %pager = %pager;
	local $FONT_SIZE = 10;
	$$title = $$title_line;
	print LOG "Preparing file system...";
	$t = time();
	my $path;
	($root, $path, undef) = fileparse($file[0]||'output', '\..*');
	for($i=0; -e "$path$root.$i"; ++$i) {}
	$root = "$path$root.$i";
	mkdir $root, 0700 or return _set_error($err, \$root);
	for my $d qw(node citers citees au so wd tg py dt la in i2 co list or graph help) {
		mkdir "$root/$d", 0700 or return _set_error($err, \"$root/$d");
	}
	do_done($t);
	print LOG 'Saving to: ', realpath($root), "\n";

	print LOG "Printing full details for records";
	print LOG " LCS >= $HTML_LCS, GCS >= $HTML_GCS.. " if $HTML_LIMITS;
	$t = time();
	my $i = 0;
	for my $id (@tl) {
		my $pub = $hra->{$id};
		if(!$HTML_LIMITS or $on_kept_graph{$pub->{tl}}
				or ($pub->{lcs} >= $HTML_LCS or $pub->{tc} >= $HTML_GCS)) { 
			my $n = $pub->{tl};
			my $f = "$root/node/$n.html";
			open NOD, ">$f" or return _set_error($err, \$f);
			print NOD ${ node2html($pub->{rid}) };
			close NOD;
			++$i;
		}
	}
	print LOG " $i files ";
	do_done($t);

	print LOG "Printing the List of all Records.. ";
	$t = time();
	do {
		use integer;
		my $pages = ($#tl + 1) / $MAIN_PI;
		++$pages if ($#tl + 1) % $MAIN_PI;
		local $HTMLPAGE = $HTML_LIMITS ? $HTMLPAGE : $pages;
		$HTMLPAGE = $pages if $HTMLPAGE > $pages;
		for my $i (keys %{ $view{main}{$VIEW} }) {
			next if 'gcs' eq $i;
			next if !$view{main}{$VIEW}{$i};
			my $index = "index-$i";
			my $final = 1 if 'tl' eq $i;
			my $PAGES = ('tl' eq $i and !$HTML_TL2) ? $pages : $HTMLPAGE;
			my $item = 0;
			for(my $p = 1; $p <= $PAGES; ++$p, $item += $MAIN_PI) {
				my $page_index = $index;
				$page_index .= "-$p" if $p > 1;
				my $f = "$root/$page_index.html";
				open HTM, ">$f" or return _set_error($err, \$f);
				print HTM ${main2html($i, $final, $item)};
				close HTM;
			}
		}
	};
	do_done($t);

	for my $ent qw(au so wd tg py dt la in i2 co) {
		my $t = $mod{$ent}{name};
		my $ar = $ari{$ent};
		next if 'wd' eq $ent and not $DO_WD;
		next if 'tg' eq $ent and not $DO_TG;
		print LOG "Printing $t..";
		$t = time();
		do {
			use integer;
			my $pages = ($#$ar + 1) / $AU_PI;
			++$pages if ($#$ar + 1) % $AU_PI;
			local $HTMLPAGE = $HTML_LIMITS ? $HTMLPAGE : $pages;
			$HTMLPAGE = $pages if $HTMLPAGE > $pages;
			for my $fi (keys %{$view{$ent}{$VIEW}}) {
				next if 'perc' eq $fi;
				next if !$view{$ent}{$VIEW}{$fi};
				my $final = 1 if 'pubs' eq $fi;
				my $PAGES = ('name' eq $fi and !$HTML_TL2) ? $pages : $HTMLPAGE;
				my $item = 0;
				for(my $p = 1; $p <= $PAGES; ++$p, $item += $AU_PI) {
					my $page_index = "list/$ent-$fi";
					$page_index .= "-$p" if $p > 1;
					my $f = "$root/$page_index.html";
					open AU, ">$f" or return _set_error($err, \$f);
					print AU ${ ausos2html($ent, $fi, $final, $item) };
					close AU;
				}
			}
		};
		@{ $pager{$ent} } = ();
		do_done($t);
	}

	if($DO_OR) {
		print LOG "Printing Cited References.. ";
		$t = time();
		my $f = "$root/list/or-pubs.html";
		open ORS, ">$f" or return _set_error($err, \$f);
		print ORS ${outs2html('pubs', 1)};
		close ORS;
		or_prep() if $needprep_or;
		for my $fi qw(ca cy so) {
			my $f = "$root/list/or-$fi.html";
			open ORS, ">$f" or return _set_error($err, \$f);
			print ORS ${outs2html($fi)};
			close ORS;
		}
		do_done($t);
	}

	open GLOSS, ">$root/glossary.html";
	print GLOSS $$glossary;
	close GLOSS;

	for $h qw(stopwords wd co) {
		open HELP, ">$root/help/$h.html";
		print HELP help($h);
		close HELP;
	}

	$t = time;
	print LOG "Printing Histograms..";
	open G, ">$root/graph/list.html";
	print G graph_list();
	close G;
	my @fi = ();
	for $k (keys %higram) {
		push @fi, $k if $higram{$k}->{enabled};
	}
	for $h (@fi) {
		open H, ">$root/graph/histo_$h.html";
		print H histogram_as_html($h, 1);
		close H;
	}
	do_done($t);

	for my $g (keys %g) {
		open G, ">$root/graph/$g.html";
		print G g2html($g{$g}, $g, 0);
		close G;
		for my $e qw(png ps) {
			my $gf = "$root/graph/$g.$e";
			my_cp("$Gtmp-$g.$e", $gf) or return _set_error($err, \$gf);
		}
	}

	my $end = time;
	my $stamp = "<!--\nStart: ". (scalar localtime $T) ."\n  End: ".
		(scalar localtime $end) ."\nPassed: ". (s2h($end-$T)) ."\n-->"; 

	open ABOUT, ">$root/about.html";
	print ABOUT $stamp, $$about, '<hr>This presentation was generated and saved using HistCite software.  Some data and features of the software may not be available.';
	close ABOUT;

	my $intro2html = '<meta http-equiv="Refresh" content="0;URL=index-tl.html">';
	open INTRO, ">$root/index.html";
	print INTRO $intro2html;
	close INTRO;

	print LOG "All steps -";
	do_done($T);
	
	$$title = $title_file;
	return "$root/index.html";
}

sub _set_error {
	my($err, $f) = @_;
	$$err = qq(Cannot create "$$f": <font color=red>$!</font>);
	print LOG "$$err\n";
	return '';
}

sub do_mark_nodes {
	my $ar = shift;
	for my $n (@{ $ar }) {
		$hrm->{$tl[$n]} = 1;
	}
}

sub do_unmark_nodes {
	my $ar = shift;
	for my $n (@{ $ar }) {
		delete $hrm->{$tl[$n]} if defined $hrm->{$tl[$n]};
	}
}

sub do_delete_nodes {
	my $ar = shift;
	my $cnt = 0;
	for my $n (@{ $ar }) {
		delete $hrm->{$tl[$n]} if defined $hrm->{$tl[$n]};
		delete $hrt->{$tl[$n]} if defined $hrt->{$tl[$n]};
		if(defined $hra->{$tl[$n]}) {
			delete $hra->{$tl[$n]};
			++$cnt;
		}
	}
	@{$pager{temp}} = ();
	return $cnt;
}

sub mark_action {
	my $ar = shift;
	my $action = shift||'';
	my $scope = shift||'';
	my $FH = shift;
	my $cnt = 0;

	if('Mark' eq $action) {
		do_mark_nodes($ar);
	} elsif('Unmark' eq $action) {
		if('all_marks' eq $scope) {
			%{$hrm} = ();
		} else {
			do_unmark_nodes($ar);
		}
	} elsif('Delete' eq $action) {
		if('all_marks' eq $scope) {
			while(my $id = each %{$hrm}) {
				if(defined $hra->{$id}) {
					delete $hrt->{$id};
					delete $hra->{$id};
					++$cnt;
				}
			}
			%{$hrm} = ();
			@{$pager{temp}} = ();
		} else {
			$cnt = do_delete_nodes($ar);
		}
	}
	if($cnt) {
		print LOG "\nDeleted $cnt records.\n";
		do { for my $m (@all_mod) { $dirty{$m} = 1 } };
		$NEEDSAVE = 1;
		do_timeline_and_network($FH);
		do_modules(undef, $FH);
		$DIRTY_CHARTS = 1;
		full_reset() if 0 == @tl;
	}
	my @n = keys %{$hrm}; $MARKS = @n; undef @n;
	@{$pager{mark}} = ();
}

sub tags_action {
	my $ar = shift;
	my $q = shift;
	my $tag = $q->param('tag')||'';
	my $tagdesc = $q->param('tagdesc')||'';
	my $tagact = $q->param('tagset');
	$tag =~ s/\s//g;
	$tag =~ s/[^-'\w]//g;
	$tag = uc $tag;
	my $c = 0;
	if($tag and 'Tag' eq $tagact) {
			$istag{$tag} = $tagdesc;
			for my $n (@$ar) {
				$hra->{$tl[$n]}->{tags} .= " $tag";
				++$c;
			}
	} elsif('Untag' eq $tagact) {
		my %temp = ();
		if($tag) {
			$temp{$tag} = 1;
		} else {
			%temp = map {($ari{tg}->[$_], 1)} ($q->param('node'));
		}
		for my $n (@$ar) {
			my $pub = $hra->{$tl[$n]};
			next unless exists $pub->{tags};
			my %t = map { ($_, 1) } split ' ', $pub->{tags};
			for my $ttag (keys %temp) {
				delete $t{$ttag};
			}
			my @t = keys %t;
			$pub->{tags} = "@t";
			++$c;
		}
	} elsif('Remove All Tags' eq $tagact) {
		for my $n (@$ar) {
			delete $hra->{$tl[$n]}->{tags};
			++$c;
		}
	}
	if($c) {
		print_ln(undef, \"Processed $c records to $tagact");
		my $t = time();
		my $rs = do_tags();
		do_done($t);
		print_ln undef, \"\t<b>$rs</b>\n";
		$dirty{tg} = 0;
		$NEEDSAVE = 1;
	}
	@{ $pager{tg} } = ();
}

sub mark_histo_form {
	my $q = shift;
	my $f = shift;

	my $range = $q->param('range')||'all';
	$m_sets_histo_range = $range;
	my $hr = $higram{$f}->{item};
	my $hrs;
	if('only' eq $range) {
		$hrs = $higram{$f}->{only};
	} elsif('shared' eq $range) {
		$hrs = $higram{$f}->{many};
	} else {
		$hrs = $higram{$f}->{item};
	}
	my(@r, @n, @a);
	if('py' eq $f) {
		@r= sort {uc $a cmp uc $b} keys %{ $hr };
	} else {
		@r= sort {
			if($hr->{$b}{n} == $hr->{$a}{n}) {
				$a cmp $b
			} else {
				$hr->{$b}{n} <=> $hr->{$a}{n}
			}
		} keys %{ $hr };
	}
	for my $i ($q->param('node')) {	#item
		@a = eval $hrs->{$r[$i]}->{nodes} if defined $hrs->{$r[$i]}->{nodes};
		push @n, @a;
	}
	mark_action(\@n, $q->param('actin'));
	undef @r; undef @n; undef @a;
}

sub mark_main_form {
	my($q, $ent, $what, $page, $FH) = @_;

	my($hr, $ari) = ($hr{$ent}, $ari{$ent});
	my $ar = $ari;
	my $main = $main{$ent}||0;
	if($main) {
		$hr = $hra; $ari = \@tl; $ar = $pager{$ent};
	}

	my $scope = $q->param('scope')||'checks_on_page';
	$m_sets_main_scope = $scope;
	$m_sets_main_field = $q->param('field')||'#';
	$m_sets_main_sign = $q->param('sign')||'gt';
	$m_sets_main_nodes = $q->param('nodes')||0;
	$m_sets_main_cites = $q->param('cites')||0;
	$m_sets_main_cited = $q->param('cited')||0;
	my(@a, @n, @r, @m, $start, $end, $exclude);

	if('checks_on_page' eq $scope) {
		if($main) {
			@n = $q->param('node');
		} else {
			for my $i ($q->param('node')) {	#item
				@a = eval $hr->{$ari->[$i]}->{nodes};
				push @n, @a;
			}
		}
	} elsif('all_marks' eq $scope) {
		@n = map { $hr->{$_}->{tl} } keys %$hrm;
	} elsif('full_list' eq $scope) {	#only for 'main'
		@n = map { $hr->{$_}->{tl} } @$ar;
	} elsif('page' eq $scope or '#' eq $m_sets_main_field) {
		$exclude = -1;
		if('page' eq $scope) {
#			$start = ($page - 1) * $MAIN_PI;
#			$end = $start + $MAIN_PI - 1;
		} elsif('range' eq $m_sets_main_sign) {
			$start = num($q->param('val1'));
			$end = num($q->param('val2'));
			--$start; --$end;
		} elsif('gt' eq $m_sets_main_sign) {
			$start = num($q->param('val1'));
			$end = $#{$ar};
		} elsif('lt' eq $m_sets_main_sign) {
			$start = 0;
			$end = num($q->param('val1'));
			$end -= 2;
		} elsif('eq' eq $m_sets_main_sign) {
			$end = num($q->param('val1'));
			$start = --$end;
		} else { #ne
			$start = 0;
			$end = $#{$ar};
			$exclude = num($q->param('val1'));
			--$exclude;
		}
		$end = $#{$ar} if $end > $#{$ar};
		$start = -1 if $end < $start;
		($start, $end) = (1, 0) if $start < 0;
		if($main) {
			for(my $i=$start; $i<=$end; ++$i) {
				next if $i == $exclude;
	#			push @n, $hra->{$r[$i]}->{tl};
				push @n, $hra->{$ar->[$i]}->{tl};
			}
		} else {
			for(my $i=$start; $i<=$end; ++$i) {
				next if $i == $exclude;
				@a = eval $hr->{$ar->[$i]}->{nodes};
				push @n, @a;
			}
		}
	} else {
		$what = $m_sets_main_field;
		my $val = num($q->param('val1'));
		my $val2 = num($q->param('val2'));
		my @i=();
		my $n=0;
		if('eq' eq $m_sets_main_sign) {
			for my $id (@{$ar}) {
				push @i, $n if $hr->{$id}->{$what} == $val;
			} continue { ++$n
			}
		} elsif('ne' eq $m_sets_main_sign) {
			for my $id (@{$ar}) {
				push @i, $n if $hr->{$id}->{$what} != $val;
			} continue { ++$n
			}
		} elsif('gt' eq $m_sets_main_sign) {
			for my $id (@{$ar}) {
				push @i, $n if $hr->{$id}->{$what} > $val;
			} continue { ++$n
			}
		} elsif('lt' eq $m_sets_main_sign) {
			for my $id (@{$ar}) {
				push @i, $n if $hr->{$id}->{$what} < $val;
			} continue { ++$n
			}
		} else { #range
			for my $id (@{$ar}) {
				push @i, $n
					if $hr->{$id}->{$what} >= $val
					&& $hr->{$id}->{$what} <= $val2;
			} continue { ++$n
			}
		}
		if($main) {
			for my $i (@i) {
				push @n, $hr->{$ar->[$i]}->{tl};
			}
		} else {
			for my $i (@i) {
				@a = eval $hr->{$ari->[$i]}->{nodes};
				push @n, @a;
			}
		}
		undef @i;
	}

	@m = @n if $m_sets_main_nodes;
	if($m_sets_main_cites) {
		for my $n (@n) {
			push @m, @{ $hra->{$tl[$n]}->{cites} };
		}
	}
	if($m_sets_main_cited) {
		for my $n (@n) {
			push @m, @{ $hra->{$tl[$n]}->{cited} };
		}
	}
	if($q->param('actin')) {
		mark_action(\@m, $q->param('actin'), $scope, $FH);
	} else {
		tags_action(\@m, $q, $FH);
	}
	undef @a; undef @n; undef @r; undef @m;
}

sub edit_form {
	my($q, $ent, $FH) = @_;

	my $hr = $hr{$ent};
	my $ari = $ari{$ent};
	my $str = trim($q->param('newedit'));
	my %f1 = qw(py 1 dt 1 la 1 so 1);

	my(@a, @n);
	my %target;
	my $items = 0;

	for my $i ($q->param('node')) {	#item
		@a = eval $hr->{$ari->[$i]}->{nodes};
		push @n, @a;
		$target{$ari->[$i]} = 1;
		if('or' eq $ent or 'ml' eq $ent) {
			$hr->{$ari->[$i]}->{cr} = uc $str;
		} else {
			$hr->{$ari->[$i]}->{name} = $str;
		}
		++$items;
	}
	return unless @n;

	my $NET_CHANGE;
	if($f1{$ent}) {
		for my $n (@n) {
			my $p = $hra->{$tl[$n]};
			$p->{$ent} = $str;
			if('so' eq $ent and 'BOOK' eq (uc $p->{pt})) {
				change_cite($p);
				$NET_CHANGE = 1;
			}
		}
	} elsif('au' eq $ent) {
		for my $n (@n) {
			my $p = $hra->{$tl[$n]};
			my @au = split '; ', $p->{au};
			my $found;
			for my $au (@au) {
				my $AU = uc $au;
				if($target{$AU}) {
					$found = 1;
					$au = $str;
					next if uc $au eq $AU;
					$dirty{au} = 1;
					if($p->{au1} eq $AU) {
						my $old_rid = $p->{rid};
						$p->{au1} = uc $str;
						change_cite($p);
						$NET_CHANGE = 1 if $old_rid ne $p->{rid};
					}
				}
			}
			$p->{au} = join '; ', @au if $found;
		}
	} elsif('or' eq $ent) {
		## WORK OR NOW ??
		$str = uc $str;
		my $new_crs = cr_normalize($str);
		for my $n (@n) {
			my $p = $hra->{$tl[$n]};
			my $i=0;
			for my $crs (@{ $p->{crs} }) {
				if($target{$crs}) {
					$crs = $new_crs;
					$p->{cr}[$i] = $str;
				}
				++$i;
			}
		}
		$NET_CHANGE = 1;

	} elsif('ml' eq $ent) {
		$str = uc $str;
		my $new_crs = cr_normalize($str);
		%target = map {$_ =~ s/ \d{4}\?$//; ($_, 1)} keys %target;	#UNPUB YEAR? rev change
		for my $n (@n) {
			my $p = $hra->{$tl[$n]};
			my $i = 0;
			for my $cr (@{$p->{cr}}) {
				if($target{$cr}) {
					$cr = $str;
					$p->{crs}[$i] = $new_crs;
				}
				++$i;
			}
		}
		$NET_CHANGE = 1;

	} elsif('in' eq $ent or 'i2' eq $ent) {
		my @src = keys %target;
		for my $s (@src) {
			$s =~ s/, +/, */;
		}
		for my $n (@n) {
			my $p = $hra->{$tl[$n]};
			for my $s (@src) {
				$p->{cs} =~ s/^( *)$s,/$1$str,/gmi;
				if($p->{rp} and (!$p->{cs} && $USE_RP or 2 == $USE_RP) ) {
					$p->{rp} =~ s/(, *)$s,/$1$str,/i;
				}
			}
			for my $f qw(in i2) {
				$p->{$f} = join "\n", $extractor{$f}->($p->{rid});
			}
		}
		$dirty{in} = $dirty{i2} = 1;
	}

	if('py' eq $ent or $NET_CHANGE) {
		if($m_defer_net) {
			$NET_DIRTY = 1;
		} else {
			do_timeline_and_network($FH);
		}
		$dirty{ml} = $dirty{or} = $dirty{$ent} = 1;
	}
	$dirty{$ent} = 1 if $items > 1;
	if($dirty{$ent}) {
		if($m_defer_net) {
			$DIRTY = 1;
		} else {
			do_modules(undef, $FH);
		}
	}

	$NEEDSAVE = 1;
	undef @a; undef @n;
}

sub goto_main_form {
	my($q, $ent) = @_;
	my $hr = $hr{$ent};
	my $main = ('main' eq $ent or 'mark' eq $ent or 'temp' eq $ent) ? 1 : 0;

	my $val = trim($q->param('valuem')||'');
	$m_sets_main_goto_value{$ent} = $val;
	my $goto_data = $q->param('data')||'#';
	$m_sets_main_goto_data{$ent} = $goto_data;
	my($i, $found);
	my $what = '#' eq $goto_data ? $PAGER{$ent} : $goto_data;
	my $what_sort = 'py' eq $what && $main ? 'tl' : $what;
	if($what_sort ne $PAGER{$ent}) {
		if($hra == $hr and 'tl' eq $what_sort) {
			@{ $pager{$ent} } = @tl;
		} elsif($main) {
			@{ $pager{$ent} } = $sorted_by{$what_sort}->($hr);
		} elsif('or' eq $ent or 'ml' eq $ent) {
			pager_sort($ent,$what_sort);
		} else {
			@{ $pager{$ent} } = $ausos_by->($what_sort, $hr);
		}
		$PAGER{$ent} = $what_sort;
	}
	my $pagr = $pager{$ent};
	$hr = $hra if $main;
	my %alpha = qw(au1 1 so 1 ca 1 name 1);
	if('tl' eq $what or '#' eq $goto_data) {
		$i = num($val) - 1;
		if($i >=0 and $i <=$#{ $pagr }) {
			$found = 1;
		} elsif($i < 0) { $i = 0;
		} else { $i = $#{ $pagr };
		}
	} elsif((('au1' eq $what or 'so' eq $what or 'ca' eq $what)
			&& $hr->{$pagr->[0]}->{$what} lt $hr->{$pagr->[$#$pagr]}->{$what})
		or ('name' eq $what && $pagr->[0] lt $pagr->[$#$pagr])
		or (!$alpha{$what}
			&& $hr->{$pagr->[0]}->{$what} < $hr->{$pagr->[$#$pagr]}->{$what})) {
		($i, $found) = goto_asc($pagr, $hr, $what, $val);
	} else {
		($i, $found) = goto_desc($pagr, $hr, $what, $val);
	}
	if($i > $#{ $pagr }) {
		$i = $#{ $pagr };
	} elsif(!$found && $i) {
		--$i;
	}
	return ($what, $i, $found);
}

sub goto_asc {
	my($pagr, $hr, $what, $val) = @_;
	my($i, $found) = (0,0);

	if('au1' eq $what or 'so' eq $what or 'ca' eq $what) {
		$val = quotemeta(uc $val);
		for($i=0; $i<=$#{ $pagr }; ++$i) {
			my $p = $hr->{$pagr->[$i]};
			if($p->{$what} =~ /^$val/) {
				$found = 1; last;
			} elsif($p->{$what} gt $val) {
				last;
			}
		}
	} elsif('name' eq $what) {
		$val = quotemeta(uc $val);
		for($i=0; $i<=$#{ $pagr }; ++$i) {
			my $v = $pagr->[$i];
			if($v =~ /^$val/) {
				$found = 1; last;
			} elsif($v gt $val) {
				last;
			}
		}
	} else {
		$val = num($val);
		for($i=0; $i<=$#{ $pagr }; ++$i) {
			my $p = $hr->{$pagr->[$i]};
			if($p->{$what} == $val) {
				$found = 1; last;
			} elsif($p->{$what} > $val) {
				last;
			}
		}
	}
	return($i, $found);
}

sub goto_desc {
	my($pagr, $hr, $what, $val) = @_;
	my($i, $found) = (0,0);

	if('au1' eq $what or 'so' eq $what or 'ca' eq $what) {
		$val = quotemeta(uc $val);
		for($i=0; $i<=$#{ $pagr }; ++$i) {
			my $p = $hr->{$pagr->[$i]};
			if($p->{$what} =~ /^$val/) {
				$found = 1; last;
			} elsif($p->{$what} lt $val) {
				last;
			}
		}
	} elsif('name' eq $what) {
		$val = quotemeta(uc $val);
		for($i=0; $i<=$#{ $pagr }; ++$i) {
			my $v = $pagr->[$i];
			if($v =~ /^$val/) {
				$found = 1; last;
			} elsif($v lt $val) {
				last;
			}
		}
	} else {
		$val = num($val);
		for($i=0; $i<=$#{ $pagr }; ++$i) {
			my $p = $hr->{$pagr->[$i]};
			if($p->{$what} == $val) {
				$found = 1; last;
			} elsif($p->{$what} < $val) {
				last;
			}
		}
	}
	return($i, $found);
}

sub search_form {
	my $q = shift;
	my $hr = $hr{temp};
	my $au = uc($s_search_author = trim($q->param('author'))||'');
	my $so = uc($s_search_source = trim($q->param('source'))||'');
	my $wd = uc($s_search_tiword = trim($q->param('tiword'))||'');
	my $py = $s_search_pubyear = trim($q->param('pubyear'))||'';

	my @t = keys %$hr;

	my @n = ();
	my @it = ();
	if($au) {
		if($au =~ /^\w+.*\*$/) {
			$au =~ s/\*//g;
			for my $it (@{$ari{au}}) {
				push @it, $it if $it =~ /^$au/;
			}
		} elsif(exists $hr{au}->{$au}) {
			@it = ($au);
		}
		if(@it) {
		local $"=', ';
			for my $au (@it) {
				if(@t) {
					for my $n (eval $hr{au}->{$au}->{nodes}) {
						push @n, $n if $hr->{$tl[$n]};
					}
				} else {
					push @n, eval $hr{au}->{$au}->{nodes};
				}
			}
		}
		refill_temp(\@n);
		@t = keys %$hr;
	}

	@n = @it = ();
	if($so) {
		if($so =~ /\*/) {
			$so =~ s/^(\w)/^$1/;
			$so =~ s/(\w)$/$1\$/;
			$so =~ s/\*/.*/g;
			for my $it (@{$ari{so}}) {
				push @it, $it if $it =~ /$so/;
			}
		} elsif(exists $hr{so}->{$so}) {
			@it = ($so);
		}
		if(@it) {
			for my $so (@it) {
				if(@t) {
					for my $n (eval $hr{so}->{$so}->{nodes}) {
						push @n, $n if $hr->{$tl[$n]};
					}
				} elsif(!$au) {
					push @n, eval $hr{so}->{$so}->{nodes};
				}
			}
		}
		refill_temp(\@n);
		@t = keys %$hr;
	}

	@n = @it = ();
	if($wd) {
		if($wd =~ /\*/) {
			$wd =~ s/^(\w)/^$1/;
			$wd =~ s/(\w)$/$1\$/;
			$wd =~ s/\*/.*/g;
			for my $it (@{$ari{wd}}) {
				push @it, $it if $it =~ /$wd/;
			}
		} elsif(exists $hr{wd}->{$wd}) {
			@it = ($wd);
		}
		if(@it) {
			for my $wd (@it) {
				if(@t) {
					for my $n (eval $hr{wd}->{$wd}->{nodes}) {
						push @n, $n if $hr->{$tl[$n]};
					}
				} elsif(!$au) {
					push @n, eval $hr{wd}->{$wd}->{nodes};
				}
			}
		}
		refill_temp(\@n);
		@t = keys %$hr;
	}

	@n = ();
	if($py) {
		my($py1,$py2);
		if($py =~ /^\d{4}$/) {
			$py1 = $py2 = $py;
		} elsif($py =~ /^(\d{4})-(\d{4})$/) {
			$py1 = $1; $py2 = $2;
			if($py2 < $py1) {
				$py2 = $py1;
				$s_search_pubyear = "$py1-$py2";
			}
		} else {
			$s_search_pubyear = '';
		}
		if($py1) {
			if(@t) {
				for my $y ($py1..$py2) {
					if(exists $hr{py}->{$y}) {
						for my $n (eval $hr{py}->{$y}->{nodes}) {
							push @n, $n if $hr->{$tl[$n]};
						}
					}
				}
			} elsif(!$au and !$so) {
				for my $y ($py1..$py2) {
					if(exists $hr{py}->{$y}) {
						push @n, eval $hr{py}->{$y}->{nodes};
					}
				}
			}
			refill_temp(\@n);
		}
	}
}

sub refill_temp {
	my $ar = shift;
	%$hrt = ();
	%$hrt = map {($tl[$_], 1)} @$ar;
}

# utility functions

sub trim {
	my $s = shift;
	if($s) {
		$s =~ s/^\s+//s;
		$s =~ s/\s+$//s;
	}
	return $s;
}

sub fix_dash {
	#fix hyphenated words split in two lines; for html view, dict, save
	my $s = shift;
	$s =~ s/\n/ /g;
	$s =~ s/\r//g;	#form input
	$s =~ s/  +/ /g;
	$s =~ s/(\w)- (\w)/$1-$2/g;
	return $s;
}

sub nbsp {
	my $s = shift;
	$s = '' if not defined $s;
	my $f = shift;
	return '&nbsp;' if '' eq $s;
	return ($f ? sprintf("%.${f}f", $s) : $s);
}

sub glink { #glossary link
	my $link = shift;
	my $tla = shift;
	my $col = shift;
	my $s = '';
	$s .= "<SPAN class=sc>" if $col;
	$s .= "<a href=\"$link\"";
	$s .= " TITLE=\" $tla{$tla} \"" if $tla{$tla};
	$s .= '>';
	$s .= $tla;
	$s .= "</a>";
	$s .= "</SPAN>" if $col;
	return $s
}

sub push2str {
	my $str = shift;
	my $val = shift;

	$$str .= ',' if defined $$str;
	$$str .= $val;
}

sub alink {
  my($a, $link, $more) = @_;

	my $ti = '';
	my $pub = $hra->{$tl[$a]};
	$ti .= "$pub->{rid} | $pub->{ci} |" if $DETAIL;
	my $t = $pub->{ti}; $t =~ s/\n/ /gs; $t =~ s/  +/ /g;
	$link = $a + 1 if (not defined $link);
	if($link =~ /^\d+$/) {
		$ti .= $pub->{dt} ? " $pub->{dt} " : 'Unknown document type';
		if($more) {
			if($pub->{j9}) {
				$ti .= $pub->{j9};
			} else {
				$ti .= substr($pub->{so}, 0, 29);
			}
			$ti .= " Title: $t";
		}
	} else {
		$ti .= " Title: $t";
	}
	$ti = encode_entities($ti);
	my $s = "<a TITLE=\"$ti\" ";
	if($LIVE or !$HTML_LIMITS or $on_kept_graph{$a}
			or $pub->{lcs} >= $HTML_LCS or $pub->{tc} >= $HTML_GCS) {
		$s .= "href=javascript:opeNod($a)>";
	} else {
		$s .= 'href=javascript:na() class=nu>';
	}
	$s .= $link;
  return "$s</a>";
}

sub lister_upLink {
	my $d = shift;
  my $a = shift;
  my $link = shift;
	my $col = shift;
	my $term = shift||'';
	$term =~ s!'!\\'!g;	#js escape
  $link = $a if (not defined $link);
  return "<a href=# OnClick=\"opeLod('$d', '$a', '$term');return false\">$link</a>";
}

sub lister_link {
	my $d = shift;
  my $a = shift;
  my $link = shift;
	my $col = shift;
  $link = $a if (not defined $link);
  return "<a href=/$d/$a class=nu>$link</a>";
}

sub window_help {
	my $path = shift;
	my $link = shift||'Help';
	my $win = shift||'help';
	my $w = shift||690;
	my $h = shift||590;
	my $o .= "<a href=# OnClick=\"window.open('$path','$win','width=$w,height=$h,resizable=yes,scrollbars=yes')\">$link</a>&nbsp;&nbsp;\n";
	return $o;
}

sub hilite {
	my $o = shift;
	my $term = shift;
	$term = quotemeta($term);
	$o =~ s!\b($term)(\b|\d+)!<span class=fnd>$1</span>$2!gi if $term;
	return $o;
}

sub do_done {
  my $t = shift;
	my $FH = shift;
	my $diff = time() - $t;
	my $st = s2h($diff);
	print_ln($FH, \(" done". ( (1 > $diff) ? '' : " in $diff secs")));
	print_ln($FH, \" ($st)") if $diff > 60;
	print_ln($FH, \"\n");
}

sub b2h {	#bytes to human
	my $s = shift;
	my $k = 1024;
	my $m = 1048576;
	my $f = '';
	if($s > $m) {
		$s /= $m; $f = 'MB';
	} elsif ($s > $k) {
		$s /= $k; $f = 'KB';
	}
	return sprintf("%.2f %s", $s, $f);
}

sub s2h {	#seconds to human
	my $s = shift;
	my $m = 60;
	my $h = 3600;
	my $o = '';
	use integer;
	if($s > $h) {
		$o = $s / $h; $s %= $h;
		$o .= ':';
	}
	$o .= sprintf("%02d", $s / $m); $s %= $m;
	$o .= ':';
	$o .= sprintf("%02d", $s);
	return $o;
}

sub view_log {
	my $file = shift||'';
	if($file) {
		open VIEWLOG, $dup_file or return 'no duplicates';
	} else {
		close LOG;
		close STDERR;
		open VIEWLOG, $log;
	}
	my $size = -s VIEWLOG;
	my $SZ = b2h($size);
	my $o = qq(<BODY BGCOLOR="white" onLoad="focus()">);
	$o .= $esclose;
	$o .= '<PRE>' unless $file;
	my $tot = 0; my $MAX = $file ? 100000 : 50000;
	my $totend = 0;
	my @o = ();
	while(read VIEWLOG, $buf, 8000) {
		if($tot < $MAX) {
			$o .= $buf;
			$tot += length $buf;
			if($tot > $MAX) {
				$o .= '></table>' if $file;
				$o .= "\n\n[ File size too big: $SZ ($size bytes)...skipping...]\n\n";
				last if $file;
			}
		} else {
			push @o, $buf;
			$totend += length $buf;
			if($totend > $MAX) {
				delete $o[0];
			}
		}
	}
	close VIEWLOG;
	$o .= "@o";
	$o .= '</PRE>' unless $file;
	unless($file) {
		open LOG, ">>$log";
		open STDERR, ">>&=LOG";
		LOG->autoflush(1);
		STDERR->autoflush(1);
	}
	$o .= '</BODY>';
	return \$o;
}

sub html_fanout_settings {
	my $o = "\n<div class=head>HTML Presentation</div>\n";
	$o .= "<INPUT onClick='check_limits(this)' type=radio name=HTML_LIMITS value=0 ${\($HTML_LIMITS ? '' : 'CHECKED')}> Apply no limits &nbsp; ";
	$o .= "<INPUT onClick='check_limits(this)' type=radio name=HTML_LIMITS value=1 ${\($HTML_LIMITS ? 'CHECKED' : '')}> Apply the following limits<p>";
	$o .= <<"";
<div id=limits style="margin-left:40px;">
Include individual record pages for records with these limits<br>
LCS&nbsp;&gt;=<INPUT type=text name=HTML_LCS size=2 value=$HTML_LCS>
or GCS&nbsp;&gt;=<INPUT type=text name=HTML_GCS size=2 value=$HTML_GCS>
<div class=tip>(Will limit individual record pages to most cited records only)</div>
<hr>
Limit analytical lists and List of All Records to
<INPUT type=text name=HTMLPAGE size=2 value=$HTMLPAGE> pages
<div class=tip>(Will restrict lists to the first pages of a sort)</div>
<br>
<INPUT type=checkbox name=HTML_TL2 ${\($HTML_TL2 ? 'CHECKED' : '')}>
Apply the above limit to date and alphabetical sorts
<div class=tip>(Unset this limit to include alpha list of <b><u>all</u></b> authors, for example, in Author List, or all records in date-sorted List of All Records)</div>
<hr>
Do not create popup lists for items<br>
with <INPUT type=text name=HTMLPUBS size=2 value=$HTMLPUBS> records or fewer
<div class=tip>(Will limit popup lists to the authors, journals, etc.<br>
with largest number of records)</div>
<br>
Limit popup lists to
<INPUT type=text name=LISTN size=2 value=$LISTN> records
<div class=tip>(Will restrict the size of popup lists)</div>
</div>
<INPUT type=Submit name=actin class=submit value=Set> &nbsp;
<INPUT type=Submit name=htmldefaults class=submit value='Default HTML Settings' OnClick="document.s.action='#html';">
<SCRIPT>
var limits = document.getElementById('limits');
function check_limits (input) {
	var f = document.forms[0];
	if(input.checked && 1==input.value) {
		limits.style.color = 'black';
		f.HTML_LCS.disabled = false;
		f.HTML_GCS.disabled = false;
		f.HTMLPUBS.disabled = false;
		f.HTMLPAGE.disabled = false;
		f.HTML_TL2.disabled = false;
	} else {
		limits.style.color = '$DIM_COLOR';
		f.HTML_LCS.disabled = true;
		f.HTML_GCS.disabled = true;
		f.HTMLPUBS.disabled = true;
		f.HTMLPAGE.disabled = true;
		f.HTML_TL2.disabled = true;
	}
}
</SCRIPT>

	return $o;
}

sub word_settings {
	my $o = <<"";
<div class=head>Word List</div>
<INPUT onClick="check_wdscope(this)" name=USE_WD_TI type=checkbox ${\($DO_USE_WD_TI ? 'CHECKED' : '')}>
Include title words
<div id=wdscope style="margin-left:40px;">
<INPUT name=USE_STOPWD type=checkbox ${\($DO_USE_STOPWD ? 'CHECKED' : '')}>
Exclude <a href="javascript:gethelp('/?help=stopwords.html')" title=" List of stop words">stop words</a><br>
Exclude words of <INPUT type=text name=SMALL_WORD size=1 value=$SMALL_WORD> characters or shorter
<div class=tip>(use 0 to disable short word elimination)</div>
<INPUT name=SPLIT_DASH type=checkbox ${\($DO_SPLIT_DASH ? 'CHECKED' : '')}>
Split hyphenated terms into words
</div><p>
<INPUT name=USE_WD_DE type=checkbox ${\($DO_USE_WD_DE ? 'CHECKED' : '')}>
Include Author keywords
<br>
<INPUT name=USE_WD_ID type=checkbox ${\($DO_USE_WD_ID ? 'CHECKED' : '')}>
Include Web of Science KeyWords Plus
<div style="margin-left:40px;">
<INPUT name=KEY_SPLIT_WORDS type=checkbox ${\($DO_KEY_SPLIT_WORDS ? 'CHECKED' : '')}>
Split multi-word terms into words<br>
<div style="position:relative;margin-left:40px;">
<INPUT name=KEY_SPLIT_DASH type=checkbox ${\($DO_KEY_SPLIT_DASH ? 'CHECKED' : '')}>
Split hyphenated terms into words<br>
</div>
<INPUT name=WD_KEY_SHOW type=checkbox ${\($DO_WD_KEY_SHOW ? 'CHECKED' : '')}>
Show keywords distinctly (in <i>italics</i>, and <b><i>bold</i></b> if found in titles as well)
</div>
<p>Show words in
<INPUT name=WD_UPPER type=radio value=1 ${\($DO_WD_UPPER ? 'CHECKED' : '')}> UPPER CASE &nbsp;
<INPUT name=WD_UPPER type=radio value=0 ${\($DO_WD_UPPER ? '' : 'CHECKED')}> lower case
<br>
<p><INPUT type=Submit name=actin class=submit value=Set>
<SCRIPT>
var wdscope = document.getElementById('wdscope');
function check_wdscope (input) {
	var f = document.forms[0];
	if(input.checked) {
		wdscope.style.color = 'black';
		f.USE_STOPWD.disabled = false;
		f.SMALL_WORD.disabled = false;
		f.SPLIT_DASH.disabled = false;
	} else {
		wdscope.style.color = '$DIM_COLOR';
		f.USE_STOPWD.disabled = true;
		f.SMALL_WORD.disabled = true;
		f.SPLIT_DASH.disabled = true;
	}
}
</SCRIPT>

	return $o;
}

sub outs_settings {
	my $o = "\n<div class=head>WoS link</div>\n";
	$o .= '<INPUT name=WOS_GW type=radio value=0 '. (0==$WOS_GW?'checked':'') .'> Universal setup<p>';
	$o .= 'Use the manual option if Universal setup does not work.  Please see help for details.<p>';
	$o .= '<INPUT name=WOS_GW type=radio value=1 '. (1==$WOS_GW?'checked':'') .' onfocus="document.s.wos_loc4.focus()"> Manual setup version 4<br>';
	$o .= <<"";
ISI Web of Knowledge 4 location URL: <INPUT name=wos_loc4 type=text class=al size=68 value="$WOS_LOC4"><p>
<SCRIPT>
function check_wosloc4 () {
	if(document.s.WOS_GW[1].checked && !(document.s.wos_loc4.value).match('^http')) {
		alert('Location URL must be given for manual setup.');
		document.s.wos_loc4.focus();
		return false;
	} else {
		return true;
	}
}
</SCRIPT>

	$o .= "<INPUT type=Submit name=actin class=submit value=Set>";
	return $o;
}

sub co_settings {
	my $o = "\n<div class=head>Country List</div>\n";
	$o .= q(Check to unify country subdivisions and variant spellings. See <a href="javascript:gethelp('/?help=countrylists.html')" title=" Country lists">Help</a> for details.<br>);
	for my $u qw(ussr uk brd ddr) {
		$o .= "<INPUT name=$u type=checkbox";
		$o .= ($unite{$u}{on} ? ' CHECKED' : '');
		$o .= "> $unite{$u}{key}<br>\n";
	}
	$o .= "<INPUT type=Submit name=actin class=submit value=Set>";
	return $o;
}

sub addr_settings {
	my $o = "\n<div class=head>Address Lists</div>\n";
	$o .= 'Use available Reprint address<br>';
	$o .= '<INPUT name=USE_RP type=radio value=0 '. (0==$USE_RP?'checked':'') .'> Never<br>';
	$o .= '<INPUT name=USE_RP type=radio value=1 '. (1==$USE_RP?'checked':'') .'> When no other address is available<br>';
	$o .= '<INPUT name=USE_RP type=radio value=2 '. (2==$USE_RP?'checked':'') .'> Always';
	$o .= "<br><INPUT type=Submit name=actin class=submit value=Set>";
	return $o;
}

sub general_settings {
	my %fs = qw(8 smallest 9 smaller 10 medium 11 larger 12 largest);
	my $o =<<"";
<div class=head>General</div>
Font size: ${\(select_box2('FONT_SIZE',\%fs))}<br>
<label><input name=TipOnStart type=checkbox ${\($TipOnStart?'checked':'')}> Show tips during program start</label><br>
<label><INPUT name=PAGE_INDX type=checkbox ${\($DO_PAGE_INDX ? 'CHECKED' : '')}>
Show page index</label>
<INPUT name=PAGE_EXT type=radio value=0 ${\($DO_PAGE_EXT ? '' : 'CHECKED')}>
Regular &nbsp; 
<INPUT name=PAGE_EXT type=radio value=1 ${\($DO_PAGE_EXT ? 'CHECKED' : '')}>
Extended<br>
<label><INPUT name=SAVE_GM_SETS type=checkbox ${\($DO_SAVE_GM_SETS ? 'CHECKED' : '')}>
Save Graph Maker settings</label><br>
<div class=subhead>Optional analysis lists</div>

#hold off patents	$o .= '<INPUT name=CI_pn_cut type=checkbox'. ($DO_CI_pn_cut ? ' CHECKED' : '') .'>';
# $o .= ' limit equivalent patent list to ';
	$o .= "<INPUT type=hidden name=CI_patents size=2 value=$CI_patents>";

	my %m = ('WD', 'Words', 'OR', 'Cited References', 'ML', 'Missing Links');
	for my $m (qw(OR WD)) {
		$o .= "<INPUT name=$m type=checkbox";
		$val = "(\$DO_$m ? ' CHECKED' : '')";
		$o .= eval $val;
		$o .= "> $m{$m} &nbsp; \n";
	}
	my $v = $view{main}{$VIEW};
	if('base' ne $VIEW and @tl and ($v->{lcsb} or $v->{lcse} or $v->{eb})) {
		$o .= "\n<br>Collection span: $net_first_year - $net_last_year\n";
		$o .= "(". ($net_last_year - $net_first_year + 1) ." years)";
		$o .= "<br>Calculation period for ";
		$o .= "LCSb: <INPUT type=text name=YEAR_B size=1 ";
		$o .= "value=$bcut_years> years, ";
		$o .= "LCSe: <INPUT type=text name=YEAR_E size=1 ";
		$o .= "value=$ecut_years> years";
		$o .= "<br>\n";
	}
	$o .=<<"";
<div class=subhead>Record lists</div>Table header interval: <INPUT type=text name=MAIN_TI size=2 value=$MAIN_TI> rows &nbsp;
Page size: <INPUT type=text name=MAIN_PI size=2 value=$MAIN_PI> rows<br>
<INPUT name=CI_au_cut type=checkbox ${\($DO_CI_au_cut ? 'CHECKED' : '')}>
Limit number of authors shown per record to
<INPUT type=text name=CI_authors size=1 value=$CI_authors> names
<div class=subhead>Analysis lists</div>Table header interval: <INPUT type=text name=AU_TI size=2 value=$AU_TI> rows &nbsp;
Page size: <INPUT type=text name=AU_PI size=2 value=$AU_PI> rows<br>
<INPUT type=Submit name=actin class=submit value=Set onClick=run_checks()> &nbsp; 
<INPUT name=defaults type=submit class=submit value="Restore All Defaults" onclick=document.forms[0].action='#all'>
<SCRIPT>function run_checks() { //placeholder
}
</SCRIPT>

	return $o;
}

sub view_settings {
	my $set = shift||'all';
	my %set;
	$set{'wd'} = &word_settings;
	$set{'or'} = &outs_settings;
	$set{'in'} = &addr_settings;
	$set{'i2'} = &addr_settings;
	$set{'co'} = &co_settings;
	$set{'html'} = &html_fanout_settings;
	$set{'all'} = &general_settings;
	my $o = qq($STD<HEAD><title>HistCite: Settings</title></HEAD><BODY VLINK=blue onLoad="focus()">);
	$o .= $esclose;

	$o .=<<"";
<STYLE>body, td { font: 10pt Verdana; background: $BG_COLOR; }
input, select { font: 10px Verdana; }
.head { font-weight: bold; font-size: 1.1em; margin-bottom: 5px; }
.subhead { font-weight: bold; margin: 3px 0 2px 0; }
.al { text-align: left } input { text-align: right }
a { text-decoration: none; }
a:hover { text-decoration: underline; color: blue; }
.tip { font-size: 8pt; margin-bottom: 4px; }
input.submit { text-align: center; margin-top: 3px; }</STYLE>
<SCRIPT>$$helpjs</SCRIPT>

	if('all' eq $set) {
		$o .= '<name id=all>';
		$o .= '<div style="text-align:center;font-weight:bold;font-size:1.1em">HistCite Settings</div>';
	} else {
		$o .= '<a href=/settings>All settings</a>'
	}
	$o .= "<FORM method=POST name=s action='' style='margin:0'>\n";
	$o .= addr_settings() .'<hr>' if 'co' eq $set;
	$o .= $set{$set};
	if('all' eq $set) {
		for my $s qw(wd or in co html) {
			$o .= "<hr><name id=$s>". $set{$s};
		}
	}
	$o .= "</FORM>\n";

	my @script = ();
	push @script, 'check_limits(document.forms[0].HTML_LIMITS[1])' if $set eq 'html' or $set eq 'all';
	push @script, 'check_wdscope(document.forms[0].USE_WD_TI)' if $set eq 'wd' or $set eq 'all';
	my $script = join '; ', @script;
	$o .= "<SCRIPT>$script</SCRIPT>" if $script;

	return $o . '</BODY>';
}

sub view_properties {
	my $o = "$STD<title>HistCite: Properties</title>";
	add_body_script(\$o, 'ui');

	$o .= <<"";
<FORM>Title: <INPUT name=title type=text size=56 value="${\(encode_entities($$title_line, '"'))}"><br>
Description:<br>
<TEXTAREA name=caption cols=64 rows=8>$$caption</TEXTAREA><br>
<INPUT type=Submit name=action value='Apply changes'><br>
Collection date of creation:
<INPUT name=moriginal type=text size=26 value="$MORIGINAL"><br>
Comment:<br>
<TEXTAREA name=comment cols=64 rows=9>$MNB</TEXTAREA>
</FORM></BODY>
<SCRIPT>setTimeout('document.forms[0].title.focus()', 100);</SCRIPT>

	return $o;
}

# citation analysis functions

sub do_timeline {
	@tl = ();
	%{$hrA} = ();
	keys(%{$hrA}) = 512;
	my $hr = shift||$hra;
	my $i = 0;
	for my $id ($order_by{perfect}->($hr)) {
		push @tl, $id;
		my $pub = $hr->{$id};
		$pub->{tl} = $i;
		$hrA->{$pub->{ci}}->{$id} = $i;
		if('P' eq $pub->{pt}) {
			#Patent may be cited by any PN listed
			my @ci;
			(undef, @ci) = split /; +/, $pub->{so};
			for my $ci (@ci) {
				$ci =~ s/-\w+$//;
				$hrA->{$ci}->{$id} = $#tl;
			}
		}
	} continue { ++$i }
	$NODES = @tl;
	@{ $pager{main} } = ();
}

sub calc_totals {
	my $hr = shift||$hra;

	$net_tgcs_num = 0;
	$net_tscs_num = 0;
	$net_tgcs = $net_tlcs = $net_tlcsx = $net_tncr = $net_tna = 0;

	while(my ($rid, $v) = each %{$hr}) {
		my $p = $hr->{$rid};
		if($p->{tc} > -1) {
			$net_tgcs += $p->{tc};
			$net_tgcs_num++;
		}
		if($p->{scs} > -1) {
			$net_tscs += $p->{scs};
			$net_tscs_num++;
		}
		$net_tlcs += $p->{lcs};
		$net_tlcsx += $p->{lcsx};
		$net_tncr += $p->{ncr};
		$net_tna += $p->{na};
	}
	print LOG "Grand Totals: LCS $net_tlcs, LCSx $net_tlcsx",
		($net_tgcs_num ? ", GCS $net_tgcs" : ', GCS n/a'),
		($net_tscs_num ? ", OCS $net_tscs" : ', OCS n/a'),
		", CR $net_tncr, NA $net_tna\n";
}

sub calc_over_t {
	my $hr = shift||$hra;
	while(my ($ci) = each %{$hr}) {
		my $t = 1 + $net_last_year - $hr->{$ci}->{py};
		my $pub = $hr->{$ci};
		my $lcs = $pub->{lcs};
		if($lcs) {
			$pub->{lcst} = $lcs / $t;
		} else {
			$pub->{lcst} = 0;
		}
		if(-1 < $pub->{tc}) {
			$pub->{gcst} = $pub->{tc} / $t;
		} else {
			$pub->{gcst} = $pub->{tc};
		}
	}
}

sub calc_lcs_cuts {
	my $hr = $hra;
	$net_mature = 0;															# how many exactly
	my $ecut_year = $net_last_year - $ecut_years;
	while(my ($ci, $v) = each %{$hr}) {
		my $cir = $hr->{$ci};
		my($lcsb, $lcse) = (0, 0);
		if(($net_last_year - $cir->{py} + 1) >= ($bcut_years + $ecut_years)) {
			my $bcut_year = $cir->{py} + $bcut_years;
			for my $n (@{$cir->{cited}}) {
				++$lcsb if $hra->{$tl[$n]}->{py} < $bcut_year;
				++$lcse if $hra->{$tl[$n]}->{py} > $ecut_year;
			}
			++$net_mature;
		} else {
			$lcsb = -1;
			$lcse = -1;
		}

		$cir->{lcsb} = $lcsb;
		$cir->{lcse} = $lcse;
		my $eb = -1;
		if($lcse == 0 && $lcsb > 0) {
			$eb = .1 / $lcsb;
		} elsif($lcsb == 0) {
			$eb = $lcse / 1;
		} elsif($lcsb > 0 && $lcse > 0) {
			$eb = $lcse / $lcsb;
		}
		$cir->{eb} = $eb;
	}
}

sub do_network {
	my $interval = shift;
	my $FH = shift;
	$ON_DE = $ON_ID = 0;
	local $| = 1;
	print $FH '<FORM name=f style=float:left;margin:0>' if $FH;
	print_ln($FH, \"Building citation network.. ");
	print $FH '<INPUT type=text name=per size=2 value=0>%</FORM>' if $FH;
	$t = time();
	for my $ci (keys %{$hra}) {
		@{ $hra->{$ci}->{cites} } = ();
		@{ $hra->{$ci}->{cited} } = ();
		@{ $hra->{$ci}->{crN} } = ();
	}
	my(@percent, @perval) = ((),());
	calc_percent_vals(\@perval, \@percent);
	my $perval = shift @perval;
	my $percent = shift @percent;
	for my $id (@tl) {
		my $pub = $hra->{$id};
		my $i = $pub->{tl};
		print 'n' unless $i % $interval;
		while($FH and $i > $perval) {
			print $FH "<script>document.f.per.value=$percent</script>";
			$perval = shift @perval;
			$percent = shift @percent;
		}
		my $n = 0;
		for my $crs ( @{ $pub->{crs} } ) {
			if(%isbook and $crs =~ /--P.+$/) {
				my $cr = cr_normalize($pub->{cr}[$n], 'asbook');
				$crs = $cr if $isbook{$cr};
			}
			if ( exists $hrA->{$crs} ) {
				my($rid, $tl, $c);
				while(($k,$v) = each %{$hrA->{$crs}}) {
					++$c;
					($rid, $tl) = ($k, $v);
				}
#				push @{ $hra->{$tl[$i]}->{cites} }, $hra->{$crs}->{tl};
				if(1 == $c) {
					push @{ $pub->{cites} }, $tl;
					push @{ $hra->{$rid}->{cited} }, $i;
					$pub->{crN}[$n] = $hra->{$rid}->{tl};
				} else {
					#process in ml
					#don't know yet; log for now
#					my @n = values %{$hrA->{$crs}};
#					for(my $n=0;$n<=$#n;++$n) { ++$n[$n] }
#					my $n = 1+$i;
#					print LOG "\nAmbiguous ref <code>$crs</code> from node $n to @n\n";
				}
			}
		} continue { ++$n }

		if('P' eq $pub->{pt}) {
			my $cpn = 0;
			for my $cp ( @{ $pub->{cp} } ) {
				my $cps = get_cpn(\$cp);
				++$cpn if $cps;
				if ($cps and exists $hrA->{$cps} ) {
					my($rid, $tl, $c);
					while(($k,$v) = each %{$hrA->{$cps}}) {
						++$c;
						($rid, $tl) = ($k, $v);
					}
					if(1 == $c) {
						push @{ $pub->{cites} }, $tl;
						push @{ $hra->{$rid}->{cited} }, $i;
					} else {
						print LOG "Ambiguous patent?: $cps\n";
					}
				}
			}
		}
		$ON_DE = 1 if $pub->{de};
		$ON_ID = 1 if $pub->{id};
	}
	for my $r (@tl) {
		my $pub = $hra->{$r};
		$pub->{lcs} = @{$pub->{cited}};
		$pub->{lcr} = @{$pub->{cites}};

		my @aus = map { uc $_ } split(/; /, $pub->{au});
		$pub->{lcsx} = 0;
		CITER: for my $c (@{$pub->{cited}}) {
			my %au_cited = map { (uc $_, 1) } split(/; /, $hra->{$tl[$c]}->{au});
			for my $au_source (@aus) {
				next CITER if $au_cited{$au_source};
			}
			++$pub->{lcsx};
		}
	}
	print $FH "<script>document.f.per.value=100</script>" if $FH;
	do_done($t, $FH);
	print $FH "\n" if $FH;
}

# save for cr_patent or $cp[0] =~ /,/) {
sub get_cpn {	# Get Cited PN
	my $cpr = shift;
	my @cp = split /\s+/, $$cpr;
	my $cp = '';
	if(1 >= @cp) {
	} else {
		$cp = $cp[0];
		$cp =~ s/-\w+$//;
	}
	return $cp;
}

sub do_list {
	my $t;
	(undef, $t) = @_;
	%{$t2{$t}} = ();
	my $hr = $t2{$t};
	for my $rid (@tl) {
		my $pub = $hra->{$rid};
		next if 'P' eq $pub->{pt};
		my @va = $pub->{$t} ? split /\n/, $pub->{$t} : ('Unknown');
		for my $v (@va) {
			my $k = uc $v;
			if('la' eq $t and $v =~ /^English$/i and $pub->{ti} =~ /^\*/) {
				#* signifies non-English title
				$v = 'Non-' . $v;
				$k = uc $v;
			}
			$hr->{$k}->{name} = $v;
			push2str \$hr->{$k}->{nodes} , $pub->{tl};
			++$hr->{$k}->{pubs};
			$hr->{$k}->{lcs} += $pub->{lcs};
			if(-1 < $pub->{tc}) {
				$hr->{$k}->{gcs} += $pub->{tc};
			}
		}
	}
	while(my $k = each %{$hr}) {
		unless(defined $hr->{$k}->{gcs}) {
			$hr->{$k}->{gcs} = -1;
			$hr->{$k}->{gcst} = -1;
		}
	}
	@{$t2i{$t}} = sort { $a cmp $b } keys %{$hr};
	for(my $i = 0; $i <= $#{$t2i{$t}}; ++$i) {
		$hr->{$t2i{$t}->[$i]}->{i} = $i;
		$hr->{$t2i{$t}->[$i]}->{n} = $i;
	}
	$hr{$t} = $hr; $ari{$t} = $t2i{$t};
	return "$items{$t}: ". @{$t2i{$t}};
}

sub do_journals {
	%jn = ();
	for my $ci (@tl) {
		my $cir = $hra->{$ci};
		next if 'P' eq $cir->{pt};
		my $jn = $cir->{so};
		push2str \$jn{$jn}->{nodes} , $cir->{tl};
		++$jn{$jn}->{pubs};
		$jn{$jn}->{name} = $jn;
		$jn{$jn}->{lcr} += $#{$cir->{cites}} + 1;
		$jn{$jn}->{lcs} += $#{$cir->{cited}} + 1;
		$jn{$jn}->{lcst} += $cir->{lcst};
		if(-1 < $cir->{tc}) {
			$jn{$jn}->{gcs} += $cir->{tc};
			$jn{$jn}->{gcst} += $cir->{gcst};
		}
	}
	while(my $k = each %jn) {
		unless(defined $jn{$k}->{gcs}) {
			$jn{$k}->{gcs} = -1;
			$jn{$k}->{gcst} = -1;
		}
	}
	@jni = sort { $a cmp $b } keys %jn;
	for(my $i = 0; $i <= $#jni; ++$i) {
		$jn{$jni[$i]}->{n} = $i;
	}
	return 'Journals: '. @jni;
}

sub cr_break {
	my $cr = shift;
	my @a = split ', ', $cr;
	@a = ('', @a) if $a[0] =~ /^\d{4}$/;
	$a[1] ||= '';
	unless($a[1] =~ /^\d{4}$/) {
		$a[2] = $a[1];
		$a[1] = -1;
	}
	$a[1] ||= -1;
	$a[2] ||= '';
	return @a[0,1,2];
}

sub cr_vp {
	my $cr = shift;
	my $doi;
	($cr, $doi) = split /, DOI /, $cr;
	my @a = split /, /, $cr;
	my @vp = ('','');
	if(2 < @a) {
		my $p = $a[$#a];
		if($p =~ /^P\w*\d+\w*$/) {
			$p =~ s/^P//;
			pop @a;
		} else {
			$p = '';
		}
		my $v = $a[$#a];
		if($v =~ /^V\w*\d+\w*$/) {
			$v =~ s/^V//;
		} else {
			$v = '';
		}
		@vp = ($v, $p, $doi);
	}
	return @vp;
}

sub change_cite {
	my $a = shift;

	$a->{ca} = $a->{au1};
	$a->{ca} =~ s/[-,']//g;
	$a->{ca} =~ s/ (\w+)$/-$1/;
	$a->{ca} =~ s/ //g;
	unless($FULL_CA) {
		#au8-1
		my @a = split /[-.]/, $a->{ca};
		my $ln = (length($a[0]) > 8) ? substr($a[0], 0, 8) : $a[0];
		my $fn = $a[1] ? substr($a[1], 0, 1) : '';
		$a->{ca} = "$ln-$fn";
	}

	$a->{rid} = "$a->{ca}-$a->{py}";
	$a->{so} = uc $a->{so};
	if('BOOK' eq (uc $a->{pt})) {
		delete $isbook{uc $a->{ci}} if $isbook{uc $a->{ci}};
		$a->{rid} .= "-$a->{so}";
		$a->{rid} =~ s/ /-/g;
		$a->{ci} = $a->{rid};
		$a->{rid} .= "-P$a->{bp}-$a->{ep}";
		$isbook{uc $a->{ci}} = 1;
	} else {
		$a->{rid} .= '-'.('' eq $a->{vl} ? '' : "V$a->{vl}");
		$a->{ci} = $a->{rid};
		$a->{rid} .= '-'.('' eq $a->{is} ? '' : "I$a->{is}");
		if($a->{ar}) {
			$a->{rid} .= "-AR$a->{ar}";
			$a->{ci} .= "-AR$a->{ar}";
		} else {
			$a->{rid} .= "-P$a->{bp}-$a->{ep}";
			$a->{ci} .= "-P$a->{bp}";
		}
	}
	$a->{ci} = uc $a->{ci};
	$a->{rid} = uc $a->{rid};
}

sub calc_percent_vals {
	my($pervalr, $percentr) = @_;
	my $pv = @tl / 100;
	my $pstep = @tl > 5000 ? 5 : 10;
	for(my $p=$pstep; $p<=100; $p+=$pstep) {
		push @{$pervalr}, ($p * $pv);
		$p = "\n$p" if 5==$pstep and 55==$p;
		push @{$percentr}, $p;
	}
}

sub do_outer {
	my $FH = shift;
	%or = ();
	#print_ln $FH, \"\t<b>***JHS***: inside do_outer.</b>\n";
	$NOR = $NLR = 0;
	print $FH "\n" if $FH;
	my(@percent, @perval) = ((),());
	calc_percent_vals(\@perval, \@percent);
	my $perval = shift @perval;
	my $percent = shift @percent;
	my $n = 0;
	for my $ci (@tl) {
		print 'o' unless $n % 1000;
		while($FH and $n > $perval) {
			print $FH " $percent%..";
			$perval = shift @perval;
			$percent = shift @percent;
		}
	
		my $pub = $hra->{$ci};
		my $i = 0;
		for my $c (@{ $pub->{crs} }) {
			next unless $c;
			my $crs;
			if('1' eq $c) {
				$crs = $pub->{cr}[$i];
			} else {
				$crs = $c;
			}
			## WORK THIS THROUGH
			unless(exists $hrA->{$crs}) {
				unless(exists $or{$crs}) {
					$or{$crs}->{cr} = $pub->{cr}[$i];
					++$NOR;
				}
				$or{$crs}->{nodes} .= "$pub->{tl},";
				++$or{$crs}->{pubs};
			}
		} continue { ++$i }

		if('P' eq $pub->{pt}) {
			for my $cp (@{ $pub->{cp} }) {
				my $cps = get_cpn(\$cp);
				next unless $cps;
				unless(exists $hrA->{$cps}) {
					$or{$cps}->{cr} = $cp;
					++$NOR unless exists $or{$cps};
#					push2str \$or{$cps}->{citer} , $pub->{tl};
					$or{$cps}->{citer} .= "$pub->{tl},";
					++$or{$cps}->{pubs};
				}
			}
		}
	} continue { ++$n }

	for my $crs (keys %{$hrA}) {
	  #print $FH "***JHS2***: hist : ".$crs;
		for my $id (keys %{$hrA->{$crs}}) {
			my $pub = $hra->{$id};
			if($pub->{lcs}) {
				unless(exists $or{$crs}) {
					my $pub2 = $hra->{$tl[$pub->{cited}[0]]};
					my $cr;
					my $i=0;
					for my $crs2 (@{$pub2->{crs}}) {
						if($crs2 eq $crs) {
							$cr = $pub2->{cr}[$i];
							last;
						}
						++$i;
					}
					$or{$crs}->{cr} = $cr;
				}
				$or{$crs}->{nodes} .= join ',', @{$pub->{cited}};
				$or{$crs}->{pubs} += $pub->{lcs};
				++$NLR;
			}
		}
	}

	print $FH " 100%  Sorting... " if $FH;
	@ori = sort { $or{$a}{cr} cmp $or{$b}{cr} } keys %or;
	local $/ = ',';
	my $i = 0;
	for my $ori (@ori) {
		$or{$ori}->{n} = $i;
		chomp $or{$ori}->{nodes};
	} continue { ++$i }
	$needprep_or = 1;
	for my $f qw(ca cy so pubs) { @{ $cache{or}{$f} } = () }
	return "Local References: $NLR\n\tGlobal References: $NOR\n\tAll Cited References: ". @ori;
}

sub or_prep {
	print LOG "Preparing Cited References for cited sorts.. ";
	my $t = time();
	for my $crs (@ori) {
		my $cr = $or{$crs};
		($cr->{ca}, $cr->{cy}, $cr->{so}) = cr_break($cr->{cr});
	}
	do_done($t);
	$needprep_or = 0;
}

sub pager_sort {
	my($ent,$what) = @_;
	my $hr = $hr{$ent};
	my $ari = $ari{$ent};

	if($what ne $PAGER{$ent} or !@{ $pager{$ent} }) {
		if('cy' eq $what) {
			@{ $cache{$ent}{$what} } = map { $hr->{$_}->{n} }
				$ausos2_by->($what,$hr,$ari) if not @{ $cache{$ent}{$what} };
			@{ $pager{$ent} } = map { $ari->[$_] } @{ $cache{$ent}{$what} };
		} elsif('pubs' eq $what) {
			@{ $cache{$ent}{$what} } = map { $hr->{$_}->{n} }
				$ausos2_by->($what,$hr,$ari) if not @{ $cache{$ent}{$what} };
			@{ $pager{$ent} } = map { $ari->[$_] } @{ $cache{$ent}{$what} };
		} elsif('cr' eq $what) {
			@{ $pager{$ent} } = @{$ari};
		} else {
			@{ $cache{$ent}{$what} } = map { $hr->{$_}->{n} }
				$orabc2_by->($what,$hr,$ari) if not @{ $cache{$ent}{$what} };
			@{ $pager{$ent} } = map { $ari->[$_] } @{ $cache{$ent}{$what} };
		}
		$PAGER{$ent} = $what;
	} elsif($change_sort_order) {
		@{ $pager{$ent} } = reverse @{ $pager{$ent} };
	}
}

sub sort_hash_abc {
	my($ar, $hr) = @_;
	@{ $ar } = sort { $a cmp $b } keys %{ $hr };
	for(my $i = 0; $i <= $#{ $ar }; ++$i) {
		$hr->{$ar->[$i]}->{n} = $i;
	}
}

sub do_wd {
	%wd = ();
	$wdN = 0;
	$wdN2 = 0;	#stopped words count
	my %w2 = ();
	$WD_PAT = $DO_SPLIT_DASH
		? q#[-\s.,!?:;'"()\[\]{}<>\/\\+*]#
		:  q#[\s.,!?:;'"()\[\]{}<>\/\\+*]#;
	my $KEY_PAT = $DO_KEY_SPLIT_WORDS
		? ($DO_KEY_SPLIT_DASH ? q![-;, ] *! : q![;, ] *! )
		: q![;,] *!;
	for my $id (@tl) {
		my $pub = $hra->{$id};
		my @k = ();
		my $k = ($ON_DE && $DO_USE_WD_DE) ? (uc $pub->{de}) : '';
		$k .= '; ' if $k;
		$k .= ($ON_ID && $DO_USE_WD_ID) ? $pub->{id} : '';
		if($DO_KEY_SPLIT_WORDS) {
			$k =~ s/[(=]/ /g;
			$k =~ s/[)]//g;
		}
		$k =~ s/\n//g; $k =~ s/  +/ /g;
		@k = split /$KEY_PAT/, $k;
		$wdN += @k;
		my %k = map { ($_, 1) } @k;

		my @w = ();
		for my $w (split /$WD_PAT/, uc fix_dash $pub->{ti}) {
			$w =~ s/^\W+//; $w =~ s/\W+$//;
			next if $w =~ /^[-\d]+$/ or '' eq $w;
			if(($DO_USE_STOPWD and $stopwd{$w}) or $SMALL_WORD >= length($w)) {
				++$wdN2 if $DO_USE_WD_TI;
			} else {
				push @w, $w;
			}
		}
		$wdN += @w if $DO_USE_WD_TI;
		my %w = map { ($_, 1) } @w;
		while(my($w) = each %w) { $w2{$w} = 1 };

		my %wk = ();
		%wk = %w if $DO_USE_WD_TI;
		while(my($k) = each %k) { $wk{$k} = 1 };

		for $w (keys %wk) {
			$wd{$w}->{name} = $w;
			push2str \$wd{$w}->{nodes} , $pub->{tl};
			++$wd{$w}->{pubs};
			$wd{$w}->{lcs} += $pub->{lcs};
			$wd{$w}->{gcs} += $pub->{tc} if -1 < $pub->{tc};
##			$wd{$w}->{orig} |= 0b01 if $w{$w};
			$wd{$w}->{orig} |= 0b10 if $k{$w};
		}
	}
	while(my $k = each %wd) {
		unless(defined $wd{$k}->{gcs}) {
			$wd{$k}->{gcs} = -1;
		}
		$wd{$k}->{orig} |= 0b01 if $w2{$k};
	}
	@wdi = sort { $a cmp $b } keys %wd;
	for($i = 0; $i <= $#wdi; ++$i) {
		$wd{$wdi[$i]}->{n} = $i;
	}
	return "Words: ". @wdi .", Word count: $wdN, All words count: ". ($wdN + $wdN2);
}

sub do_tags {
	%tg = ();
	for my $id (keys %{$hra}) {
		my $pub = $hra->{$id};
		my $tgs = $pub->{tags};
		my %t;
		if($tgs) {
			%t = map { ($_, 1) } split ' ', $tgs;
			my @t = keys %t;
			$pub->{tags} = "@t";
		} else {
			%t = ('Other', 1);
		}
		while(my $tg = each %t) {
			$tg{$tg}->{name} = $istag{$tg};
			push2str \$tg{$tg}->{nodes} , $pub->{tl};
			++$tg{$tg}->{pubs};
			$tg{$tg}->{lcs} += $pub->{lcs};
			$tg{$tg}->{gcs} += $pub->{tc} if -1 < $pub->{tc};
		}
	}
	while(my $k = each %tg) {
		unless(defined $tg{$k}->{gcs}) {
			$tg{$k}->{gcs} = -1;
		}
	}
	@tgi = sort { $a cmp $b } keys %tg;
	for($i = 0; $i <= $#tgi; ++$i) {
		$tg{$tgi[$i]}->{n} = $i;
	}
	$TAGS = @tgi;
	if($TAGS > 1 or ($TAGS == 1 && not defined $tg{Other})) {
		$DO_TG = 1;
	} else {
		$DO_TG = 0;
	}
	return "Tags: ". @tgi;
}

sub do_authors {
	%au = ();
	for my $id (@tl) {
		my @au = split /; /, $hra->{$id}->{au};
		my $pub = $hra->{$id};
		for my $au (@au) {
			my $AU = uc $au;
#			$AU =~ s/'//g;	think this thru; hilite how
			$au{$AU}->{name} = $au;
			push2str \$au{$AU}->{nodes} , $pub->{tl};
			++$au{$AU}->{pubs};
			$au{$AU}->{lcr} += $#{$pub->{cites}} + 1;
			$au{$AU}->{lcs} += $#{$pub->{cited}} + 1;
			$au{$AU}->{lcst} += $pub->{lcst};
			if(-1 < $pub->{tc}) {
				$au{$AU}->{gcs} += $pub->{tc};
				$au{$AU}->{gcst} += $pub->{gcst};
			}
			$au{$AU}->{lcsb} += $pub->{lcsb} if -1 < $pub->{lcsb};
			$au{$AU}->{lcse} += $pub->{lcse};
			$au{$AU}->{lcsx} += $pub->{lcsx};
		}
	}
	while(my $k = each %au) {
		unless(defined $au{$k}->{gcs}) {
			$au{$k}->{gcs} = -1;
			$au{$k}->{gcst} = -1;
		}
		$au{$k}->{lcsb} = -1 unless defined $au{$k}->{lcsb};
	}
	@aui = sort {$a cmp $b} keys %au;
	for (my $i = 0; $i <= $#aui; ++$i) {
		$au{$aui[$i]}->{n} = $i;
	}
	return 'Authors: '. @aui;
}

=pod do_missed()

Process possible missing links

=cut

sub do_missed {
## WORK HERE HERE HERE WORK
	my $FH = shift;
	my $t = time();
	%ml = ();
	%ay4ml = ();	#REVIEW
	%cr4ml = ();

#	open AC, ">ac";
	my $i = 0;
	for my $id (@tl) {
		my $pub = $hra->{$id};
		next if 'P' eq $pub->{pt};
		my $crs = $pub->{ci};
#		$crs =~ /^(.+?-\d{4})-/;
#		print "\nOOPS no ay? in '$pub->{ci}'" unless $1;
#		my $ay = $1;
		my $ay = "$pub->{ca}-$pub->{py}";
#		print AC "\n$ay $i";
		push @{ $ay4ml{$ay} }, $i;

#		$ci =~ /(^\d{4}).*-(V\d+)/;
#		next if not defined $1 or not defined $2;
#		my $s_cite = "$au-$1-$2";
#		my $s_cite = "$au-$pub->{py}-";
#		$s_cite .= "V$pub->{vl}" if $pub->{vl};
#		$crs =~ s/-P\d+$//;
		$crs =~ s/-P$pub->{bp}$//;
#		print AC " '$crs'";
		push @{ $cr4ml{$crs} }, $i;
	} continue { ++$i }
#	close AC;
#	print $FH "\n first loop " if $FH;
#	do_done($t, $FH);
#	my @k = keys %au_miss; print "\nau_miss = ". @k;
#	@k = keys %ci_miss; print "\nci_miss = ". @k ."\n";

	print $FH "\n" if $FH;
	my(@percent, @perval) = ((),());
	calc_percent_vals(\@perval, \@percent);
	my $perval = shift @perval;
	my $percent = shift @percent;
	my $tl = 0;
	local $|=1;
	for my $id (@tl) {
		print 'm' unless $tl % 1000;
		while($FH and $tl > $perval) {
			print $FH " $percent%..";
			$perval = shift @perval;
			$percent = shift @percent;
		}
		my $pub = $hra->{$id};
		my $i = 0;
		for my $crs ( @{ $pub->{crs} }) {
			my $cr = $pub->{cr}[$i];
			if(exists $hrA->{$crs}) {
				my @sims = values %{$hrA->{$crs}};
				next if 1 == @sims;
				$ml{$cr}->{cr} = $cr;
				++$ml{$cr}->{pubs};
				$ml{$cr}->{nodes} .= "$tl,";
				push @{$ml{$cr}->{like}}, @sims;

#			} elsif( $crs =~ /-(0000-|IN.PRESS|UNPUB|TO.BE.PUB)/ ) {
			} elsif( $crs !~ /-\d{4}/ ) {
#				$crs =~ /^(\w+-\w+)-/;
#				print " $crs : $cr\n" if not defined $1;
#				next if not defined $1;	#how about ANON?  *BAT MAN PROJ
#				my $au = $1;
				my($au) = split /,/, $cr, 2;
				$au =~ s/ /-/g;
				unless($FULL_CA) {
					#au8-1
					my @a = split /[-.]/, $au;
					my $ln = (length($a[0]) > 8) ? substr($a[0], 0, 8) : $a[0];
					my $fn = $a[1] ? substr($a[1], 0, 1) : '';
					$au = "$ln-$fn";
				}
				my $py = $pub->{py};
				$cr .= " $py?";
				for my $y ($py, 1+$py) {
					next unless $ay4ml{"$au-$y"};
					$ml{$cr}->{cr} = $cr;
					++$ml{$cr}->{pubs};
					$ml{$cr}->{nodes} .= "$tl,";
					push @{$ml{$cr}->{like}}, @{ $ay4ml{"$au-$y"} };
				}

			} else {
				my $s_cite = $crs;
				$s_cite =~ s/-P\w+$//;

				next unless $cr4ml{$s_cite};
				$ml{$cr}->{cr} = $cr;
				++$ml{$cr}->{pubs};
				$ml{$cr}->{nodes} .= "$tl,";
				for(@{ $cr4ml{$s_cite} }) {
					if ( not $id eq $tl[$_] ) {
						push @{$ml{$cr}->{like}}, $_;
	#				push2str \$ml{$cr}->{nodes}, $tl;
	#					($ml{$cr}->{ca}, $ml{$cr}->{cy}, $ml{$cr}->{so}) = cr_break($cr);
					} 
				}
			}
		} continue { ++$i }
	} continue { ++$tl }

	for my $cr (keys %ml) {
		my %h = map {($_,1)} split /,/, $ml{$cr}->{nodes};
		my @n = sort { $a <=> $b } keys %h;
		%h = ();

		%h = map {($_,1)} @{$ml{$cr}->{like}};
		for my $n (@n) {
			delete $h{$n};# if exists $h{$n};
		}
		if(%h) {
			@{$ml{$cr}->{like}} = sort { $a <=> $b } keys %h;
			$ml{$cr}->{nodes} = join ',', @n;
			$ml{$cr}->{pubs} = @n;
		} else {
			delete $ml{$cr}; next;
		}
	}
	print $FH " 100%  Sorting... " if $FH;

	@mli = ();
	for my $cr (sort { $a cmp $b } keys %ml) {
		push @mli, $cr;
	}
	$i = 0;
#	open ML, ">ml";
	for my $mli (@mli) {
		$ml{$mli}->{n} = $i;
		($ml{$mli}->{ca}, $ml{$mli}->{cy}, $ml{$mli}->{so}) = cr_break($mli);
		if($ml{$mli}->{cy} == -1 and $ml{$mli}->{so} =~ s/ (\d{4})\?$//) {
			$ml{$mli}->{cy} = $1;
		}
#		print ML "$mli\n";
	} continue { ++$i }
#	close ML;
	for my $f qw(ca cy so pubs) { @{ $cache{ml}{$f} } = () }
	return 'Missing links: '. @mli;
}

# presentation functions

sub node2dump {
	my $id = shift;
	return '<pre>'. Dumper($hr->{$id}) ."</pre>";
}

sub node2html {
	my $ci = shift;
	my $changed = shift;
	my $msg = shift||'';

	my $cir = $hra->{$ci};
	my $ispatent = 1 if 'P' eq $cir->{pt};
	my $o = '';
	my $node = 1 + $cir->{tl};
	$o .= "$STD<TITLE>HistCite - Record $node: ";
	$o .= encode_entities(fix_dash($cir->{ti})) ."</TITLE>\n";
	add_body_script(\$o);
	$o .= $msg;
	$o .= "<TABLE border=0 cellpadding=5 cellspacing=0 width=100%><TR>";
	$o .= "<TD class=ui align=left>Record $node &nbsp; View: $view{$VIEW}\n";
	$o .= "&nbsp;&nbsp;<a href=edit-$cir->{tl}.html style=text-decoration:none;>Edit</a>\n" if $LIVE and !$ispatent;
	add_close_link(\$o) if $changed;
	$o .= "<a href=# OnClick=\"window.open('dump-$cir->{tl}.html','dump$cir->{tl}','resizable=yes,scrollbars=yes');return false\">Dump</a>\n"
		if $LIVE and $DETAIL;
	$o .= '<TD align=right>'. (guide('nn')) unless $LIVE;
	$o .= '</div></TABLE>';

	$o .= <<"";
<STYLE>
.row {
	margin: 2px; padding: 3px;
}
.field {
	font-weight: bold;
}
.cr {
	white-space: nowrap; line-height: 1.5em;
}
.bar { background-color: #000; line-height: 8px; margin: 0 0 2px 4px; font-size: 6px; }
</STYLE>

	$o .= "<TABLE border=0><TR valign=top><TD>\n";
	for my $f (@a_prefs) {
		if ('cr' eq $f) {
			my $br = '<br>';
			if($ispatent) {
				$o .= "<div class=row><b>Cited Patents:</b>\n";
				$o .= list_cp($cir);
				$o .= '</div>';
				$o .= "<br><b>Cited Articles:</b>\n";
				$o .= '<div>';
				$br = '<br><br>';
			} else {
				$o .= "<div class=row><div class=field>$f{$f}:</div><div class=cr>";
			}
			for (my $n=0; $n <= $#{ $cir->{cr} }; ++$n) {
				my $cr = encode_entities($cir->{cr}[$n], '<>"&');
				if ( defined $cir->{crN}[$n] ) {
					$o .= alink($cir->{crN}[$n], $cr, 1);
				} else {
					$cr = "<b>$cr</b>" unless $cr =~ / /;
					$o .= $cr;
				}
				$o .= " | $cir->{crs}[$n]" if $DETAIL;
				$o .= "$br\n";
			}
			$o .= '</div>';
			$o .= '&nbsp;' if 0 > $#{$cir->{cr}};

		} elsif('au' eq $f) {
			$o .= "<div class=row><span class=field>$f{$f}:</span> ";
			$o .= ${ full_authors($cir) };

		} elsif ('scores' eq $f) {
			$o .= "<div class=row>";
			$o .= node_scores($cir);

		} else {
			next if 'ae' eq $f and not $ispatent;
			$o .= "<div class=row><span class=field>$f{$f}:</span> ";
			$o .= '<span class="ci_title">' if 'ti' eq $f;
			my $fc = 0;
			for(split /:/, $f) {
				next if 'vipp' eq $_ and $ispatent;
				if($fc > 0) {
					$o .= ' :' if $_ ne 'vipp';
					$o .= ' ';
				}
				if (defined $cir->{$_}) {
					if ('' eq $cir->{$_}) {
						$o .= '&nbsp;';
					} else {
						my $s = ($pt{$cir->{$_}} ? $pt{$cir->{$_}} : $cir->{$_});
						$s = fix_dash($s) if ('ti' eq $f or 'ab' eq $f) and not $ispatent;
		##test				$s = encode_entities($s);
						if($s =~ /software tool for i/) {
							print " >> $s <<\n";
							open OUT, ">testout";
							print OUT $s;
							close OUT;
						}
	## was this test					$s = "$s<br>$s";
						$s =~ s/\n/<br>\n/g if 'cs' eq $f or 'rp' eq $f or 'ae' eq $f
							or 'em' eq $f
							or ('ab' eq $f and $ispatent);
						$o .= $s;
					}
				} else {
					$o .= '&nbsp;';
				}
				++$fc;
			}
			$o .= '</span>' if 'ti' eq $f;
			if('py' eq $f) {
				my $pd = $cir->{pd};
				$pd =~ s/\n/<br>\n/g if $ispatent;
				$o .= " $mon[$cir->{pdm}] $cir->{pdd}<br>\n" if $ispatent;
				$o .= ($ispatent ? $pd : "&nbsp;$pd");
			}
		}
		$o .= '</div>';
		$o .= "\n";
	}
	if('base' ne $VIEW) {
		my $v = $view{main}{$VIEW};
		$o .= "<TD>\n";
		my $lcs_watch = $v->{lcs} || $v->{lcst} || $v->{lcsb} || $v->{lcse} || $v->{eb};
		if($lcs_watch && 0 < $cir->{lcs}) {
			my %lcs;
			for my $a (@{ $cir->{cited} }) {
				++$lcs{$hra->{$tl[$a]}->{py}};
			}
			my $lcs = 0;
			$o .= <<'';
<style>table.hi td { padding-right: 4px; font-size: 10px; }
table.hi td a { text-decoration: none; color: black; cursor: default; }
table.hi td a:hover { text-decoration: none; color: black; }</style>
<TABLE border=0 cellspacing=0 cellpadding=0 class=hi>
<TR align=right><TD>year<TD><a href=# title=" Cumulative LCS ">C</a>
<TD><a href=# title=" LCS received each year ">L</a>

			my($bcut_year,$ecut_year) = (0,0);
			$ecut_year = $net_last_year - $ecut_years;
			if(($net_last_year - $cir->{py} + 1) >= ($bcut_years + $ecut_years)) {
				$bcut_year = $cir->{py} + $bcut_years;
			}
			my $yo;
			my $be_stat = $v->{lcsb} || $v->{lcse} || $v->{eb};
			for(my $y = $cir->{py}; $y <= $net_last_year; ++$y) {
				$o .= "<TR align=right valign=bottom><TD>";
				$yo = $y;
				$yo = "<b>$yo</b>"
					if $be_stat && $bcut_year && ($y < $bcut_year or $y > $ecut_year);
				$o .= "$yo<TD";
				if(defined $lcs{$y}) {
					$lcs += $lcs{$y};
					$o .= " class=sc>$lcs";
					$o .= "<TD>$lcs{$y}";
					$o .= "<TD align=left><div class=bar style=width:";
					$o .= (2 * $lcs{$y}) .'px;>.</div>';
				} elsif($lcs) {
					$o .= " class=sc>$lcs";
				} else {
					$o .= '>';
				}
				$o .= "\n";
			}
			$o .= "</TABLE><p><br>\n";
		}
		my @f = ();
		for my $f qw(lcsb lcse eb lcst gcst) {
			push @f, $f if $v->{$f};
		}
		my @s = ();
		for my $f (@f) {
			my $v = $cir->{$f};
			$v = '' if $v == -1 ;
			$v = show_lcseb($cir) if 'eb' eq $f;
			if($f{$f} =~ m!/t!) {
				$v = nbsp($v, $dec{$f});
			}
			push @s, "<a class=scr title='$tla{$f{$f}}'><b>$f{$f}</b>:&nbsp;$v</a>";
		}
		do { local $" = "<p>\n"; $o .= "@s"};
	}
	$o .= "</TABLE>\n";
	$o .= "</BODY>";
	return \$o;
}

sub list_cp {	#List Cited Patents
	my $pub = shift;
	my $o = "<code>\n";
	my $br = '<br><br>';
	for my $cp (@{ $pub->{cp} }) {
		my $cps = get_cpn(\$cp);
		my $s;
		if ($cps) {
			$s = encode_entities($cp);
			if (exists $hrA->{$cps} ) {
				my @tl = values %{$hrA->{$cps}};
				$s = alink($tl[0], $s);
			}
		} else {
			$s = "<b>$cp</b>";
		}
		$o .= $s;
		$o .= "$br\n";
	}
	$o .= "</code>\n";
}

sub node_scores {
	my $pub = shift;
	my @s;
	my $o;
	for my $sf qw(lcr ncr lcs tc scs) {
		my $v;
		$v = $pub->{$sf};
		if('P' eq $pub->{pt} and 'ncr' eq $sf) {
			my $cr = count_crs($pub->{crs});
			$v .= " (${\( $pub->{ncr} - $cr)}+$cr)";
		}
		$v = '' if -1 == $v ;
		push @s, "<a class=scr title='$tla{$f{$sf}}'><B>$f{$sf}</B>:&nbsp;$v</a>";
	}
	$o = join ' &nbsp; ', @s;
	return $o;
}

sub edit_node2html {
	my $tl = shift;
	my $cri = shift;

	my $note = '';
	my $a = defined $tl ? $hra->{$tl[$tl]} : '';

	my($o,$node,$titl) = ('','Record ','');

	unless($a) {
		$a = { au => '', af => '', ti => '', vipp => '', py => '', rid => '',
			pd => '', pdm => '', pdd => '', ga => '', j9 => '', em => '',
			vl => '', is => '', bp => '', ep => '', ar => '', di => '',
			pt => 'Journal', dt => 'Article', la => '', rf => '', tc => -1, cs => '', 
			lcs => 0, lcr => 0, ncr => 0,
			ci => '', ut => '', rp => '',
			so => '', ab => '', nb => ''
		};
		$a->{cr} = [];
		if(defined $cri) {
			my $crs = $ori[$cri];
			my $cr = $or{$crs}->{cr};
			($a->{au}, $a->{py}, $a->{so}) = cr_break($cr);
			$a->{py} = '' if -1 == $a->{py};
			($a->{vl}, $a->{bp}, $a->{di}) = cr_vp($cr);
			$a->{j9} = $a->{so};
			$note = " Converting the following Cited Reference to a record:<p><div align=center><code>$cr</code></div>\n";
#		print "\n$crs\n$cr\n";
		}
		$titl = 'New';
	} else {
		$node .= 1 + $a->{tl} if $a->{rid};
		$titl = 'Edit';
	}

	$o = "$STD<title>HistCite - $titl $node</title>";
	add_body_script(\$o);
	$o .= "<FORM method=POST action=edit_node>\n &nbsp; <span class=ui>";
	$o .= $note ? $note : "$titl $node";
	$o .= '</span> &nbsp; ';

	$o .= "<INPUT class=ui type=submit value=\"Apply changes\">";
	$o .= "<INPUT name=rid type=hidden value=\"$a->{rid}\">\n";
	$o .= "<INPUT name=cri type=hidden value=\"$cri\">\n" if defined $cri;
	$o .= '<TABLE border=0 cellpadding=5>';
	my $au = ${ full_authors($a) }; $au =~ s/; /\n/g;
	$o .= "<TR><TH align=right valign=top>Author(s)<td><TEXTAREA name=au cols=48 rows=3>$au</TEXTAREA>\n";
	$o .= "<TR><TH align=right valign=top>Title<td><TEXTAREA name=ti cols=72 rows=2 style='font-weight:bold'>$a->{ti}</TEXTAREA>\n";
	$o .= "<TR><TH align=right valign=top>Source<td><INPUT name=so type=text size=72 value=\"$a->{so}\">\n";
	$o .= "<br>Volume: <INPUT name=vl type=text size=5 value=\"$a->{vl}\"> ";
	$o .= "Issue: <INPUT name=is type=text size=5 value=\"$a->{is}\"> ";
	if($a->{rid} and $a->{ar}) {
		$o .= "Art. No.: <INPUT name=ar type=text size=8 value=\"$a->{ar}\"> ";
	} else {
		$o .= "Start page: <INPUT name=bp type=text size=5 value=\"$a->{bp}\"> ";
		$o .= "End page: <INPUT name=ep type=text size=4 value=\"$a->{ep}\">\n";
	}
	$o .= "<br>Source Abbrev.: <INPUT name=j9 type=text size=30 value=\"$a->{j9}\">\n";
	$o .= "<TR><TH align=right>Date<td>Year: <INPUT name=py type=text size=4 value=\"$a->{py}\">\n";
	my ($mo, $day) = split / /, $a->{pd};
	$mo = '' unless $mo; $day = '' unless $day;
	$o .= "Month: <SELECT name=mon>\n";
	$o .= "<OPTION value=\"$mo\" selected>$mo\n" if '' eq $mo;
	$o .= "<OPTION value=\"$mo\" selected>$mo\n" if $mo =~ /^\D{3}/ and not $mo eq $mon[$a->{pdm}];
	for(my $m=1; $m <= $#mon; ++$m) {
		$o .= "<OPTION value=$mon[$m]";
		$o .= " selected" if $m eq $a->{pdm} and $mo eq $mon[$m];
		$o .= ">$mon[$m]\n";
	}
	$o .= "</SELECT>\n";
	$o .= "Day: <INPUT name=day type=text size=2 value=\"$day\">\n";
	$o .= "<TR><TH align=right valign=top>Type<td>";
	$o .= "Publication: <INPUT name=pt type=text size=16 value=\"$a->{pt}\">\n";
	$o .= "Document: <INPUT name=dt type=text size=16 value=\"$a->{dt}\">\n";
	$o .= '<TR><TH align=right valign=top>DOI <td>';
	$o .= "<INPUT name=di type=text size=42 value=\"${\($a->{di}?$a->{di}:'')}\">";
	$o .= "<TR><TH align=right valign=top>Language<td>";
	$o .= "<INPUT name=la type=text size=16 value=\"${\($a->{la}?$a->{la}:'')}\">\n";
	$o .= "<TR><TD colspan=2 align=left>";
	$o .= "<b>LCR</b>: $a->{lcr}";
	$o .= " &nbsp;&nbsp;<b>CR</b>: $a->{ncr}";
	$o .= " &nbsp;&nbsp;<b>LCS</b>: $a->{lcs}";
	$o .= " &nbsp;&nbsp;<b>GCS</b>: <INPUT name=tc size=3 value=${\(-1==$a->{tc}?'':$a->{tc})}>\n";

	my $cols = $ie ? 80 : 65;
	$o .= "<TR><TH align=right valign=top>Comment<td><TEXTAREA name=nb cols=$cols rows=5>$a->{nb}</TEXTAREA>\n";
	$o .= "<TR><TH align=right valign=top>Address<td><TEXTAREA name=cs cols=$cols rows=3>$a->{cs}</TEXTAREA>\n";
	$o .= "<TR><TH align=right valign=top>Reprint<td><TEXTAREA name=rp cols=$cols rows=2>$a->{rp}</TEXTAREA>\n";
	$o .= "<TR><TH align=right valign=top>E-mail<td><TEXTAREA name=em cols=50 rows=2>$a->{em}</TEXTAREA>\n";

	local $" = "\n";
	my $rows = ($#{$a->{cr}} > -1 ? $#{$a->{cr}} : 25); ++$rows;
	$o .= "<TR><TD valign=top colspan=2><b>Cited References:</b><br><TEXTAREA name=cr cols=$cols rows=$rows>@{$a->{cr}}</TEXTAREA></TD>\n";
	$o .= "<TR><TD valign=top colspan=2><b>Abstract:</b><br><TEXTAREA name=ab cols=$cols rows=22>$a->{ab}</TEXTAREA>\n";
	$o .= "</TABLE>";
	$o .= "<INPUT class=ui type=submit value=\"Apply changes\">";
	$o .= "</FORM>";

	return \$o;
}

sub edit_node {
	my $q = shift;
	my $a;
	# rid au ti so vl is bp ep py mon day pt dt tc nb cs cr ab rp j9

	my $rid = $q->param('rid');
	my $cri = $q->param('cri');
	do { local $" = '; '; my @au = split /\r\n/, trim($q->param('au'));
		my @af = ();
		my $eofull_names = 0;
		for my $au (@au) {
			if($au =~ s/\s*\((.+)\)//) {
				push @af, $1 unless $eofull_names;
			} else {
				$eofull_names = 1;
			}
			$au = trim($au);
		}
		$a->{au} = "@au"; $a->{au} =~ s/,//gs; $a->{au} =~ s/ +/ /g;
		$a->{au1} = uc $au[0];
		$a->{na} = @au;
		@af = map trim($_), @af;
		$a->{af} = "@af";
	};
	$a->{ca} = $a->{au1};
	$a->{ca} =~ s/[-,']//g;
	$a->{ca} =~ s/ (\w+)$/-$1/;
	$a->{ca} =~ s/ //g;
	unless($FULL_CA) {
		#au8-1
		my @a = split /[-.]/, $a->{ca};
		my $ln = (length($a[0]) > 8) ? substr($a[0], 0, 8) : $a[0];
		my $fn = $a[1] ? substr($a[1], 0, 1) : '';
		$a->{ca} = "$ln-$fn";
	}

	for my $t qw(ti so vl is bp ep ar py pt dt di la tc nb cs ab rp j9 em) {
		if(defined $q->param($t)) {
			$a->{$t} = trim($q->param($t));
		} else {
			$a->{$t} = '';
		}
	}
	$a->{tc} = -1 if '' eq $a->{tc};
	$a->{so} = uc $a->{so};
	$a->{rid} = "$a->{ca}-$a->{py}";
	if('BOOK' eq (uc $a->{pt})) {
		$a->{rid} .= "-$a->{so}";
		$a->{rid} =~ s/ /-/g;
		$a->{ci} = $a->{rid};
		$a->{rid} .= "-P$a->{bp}-$a->{ep}";
		$isbook{uc $a->{ci}} = 1;
	} else {
		$a->{rid} .= '-'.('' eq $a->{vl} ? '' : "V$a->{vl}");
		$a->{ci} = $a->{rid};
		$a->{rid} .= '-'.('' eq $a->{is} ? '' : "I$a->{is}");
		if($a->{ar}) {
			$a->{rid} .= "-AR$a->{ar}";
			$a->{ci} .= "-AR$a->{ar}";
		} else {
			$a->{rid} .= "-P$a->{bp}-$a->{ep}";
			$a->{ci} .= "-P$a->{bp}";
		}
	}
	$a->{ci} = uc $a->{ci};
	$a->{rid} = uc $a->{rid};

	$a->{vipp} = vipp($a->{vl}, $a->{is}, $a->{bp}, $a->{ep}, $a->{ar});

	my @cr = split /\r\n/, uc trim($q->param('cr')); $a->{cr} = [ @cr ];
	$a->{crs} = [ map cr_normalize($_), @cr ];
	$a->{ncr} = 1 + $#{$a->{cr}};

	for my $t qw(ti nb cs ab rp) {	#TA fix
		$a->{$t} =~ s/\r//gs;
	}

	my($mon, $day) = map trim($_), ($q->param('mon'), $q->param('day'));
	if($day and $mon) {
		$a->{pd} = "$mon $day";
	} elsif($mon) {
		$a->{pd} = $mon;
	} else {
		$a->{pd} = '';
	}
	($a->{pdm}, $a->{pdd}) = date_analysis($a->{pd});

	my $msg;
	my($CITE_CHANGE, $CR_CHANGE, $ADDR_CHANGE, $SCORE_CHANGE) = ('','','','');
	if($rid) {
		#print "\n$rid ? $a->{rid}\n";
		for my $t qw(rid au af ca na ti so vl is bp ep ar j9 em py pd pdm pdd pt dt la tc nb cs rp ab ncr vipp ci) {
			$NEEDSAVE = 1 if $hra->{$rid}->{$t} ne $a->{$t};
		}
		if($rid ne $a->{rid}) {
			$CITE_CHANGE = 1;
			#print "\nChanging in root: $rid ne $a->{rid}\n";
			delete $hra->{$rid};
			if(defined $hrm->{$rid}) {
				delete $hrm->{$rid};
				$hrm->{$a->{rid}} = 1;
				@{$pager{mark}} = ();
			}
			if(defined $hrt->{$rid}) {
				delete $hrt->{$rid};
				$hrt->{$a->{rid}} = 1;
				@{$pager{temp}} = ();
			}
		} else {
			#print "\nUpdating in root\n";
			my $pub = $hra->{$rid};
			if($#{ $a->{crs} } != $#{ $pub->{crs} }) {
				$CR_CHANGE = 1;
			} else {
				my $i = 0;
				for my $cr (@{ $a->{cr} }) {
					if(uc $cr ne $pub->{cr}[$i]) {
						$CR_CHANGE = 1; last;
					}
				} continue { ++$i }
			}
			$ADDR_CHANGE = $pub->{cs} ne $a->{cs} ? 1 : 0;
			$SCORE_CHANGE = $pub->{tc} ne $a->{tc} ? 1 : 0;
			if($pub->{ti} ne $a->{ti}) {
				$dirty{wd} = $DIRTY = 1;
				$dirty{la} = 1 if $pub->{ti} =~ /^\*/ or $a->{ti} =~ /^\*/;		#tricky;
					#removal/add of * from/to ti may or may not need to trigger this
					#* signifies non-English title
			}
			for my $f qw(dt la au so) {
				if($pub->{$f} ne $a->{$f}) {
					$dirty{$f} = 1; $DIRTY = 1;
				}
			}
		}
		$hra->{$a->{rid}}->{$t} = $a->{rid};
		my $pub = $hra->{$a->{rid}};
		for my $t qw(rid au au1 af ca na ti so vl is bp ep ar j9 em py pd pdm pdd pt dt di la tc nb cs rp ab ncr vipp ci) {
			$pub->{$t} = $a->{$t};
		}
		for my $t qw(cr crs) {
			@{$pub->{$t}} = @{$a->{$t}};
		}
	} else {
		if($hra->{$a->{rid}}) {
	#		print "\nAlready there\n";
			$msg = '<font color=red>The record already exists.</font> Try to <font color=blue>Edit</font> it instead.<p>';
		} else {
	#		print "\nNEW\n";
			$CITE_CHANGE = 1;
			$hra->{$a->{rid}} = $a;
			$ADDR_CHANGE = 1;
			if(defined $cri and $a->{ci} eq $ori[$cri]) {	#converted from Outer CR
				print LOG "\nnew record converted from $or{$ori[$cri]}->{cr}";
			}
		}
	}
	if($ADDR_CHANGE or $CITE_CHANGE) {
		for my $f qw(in i2 co) {
			$hra->{$a->{rid}}->{$f} = join "\n", $extractor{$f}->($a->{rid});
			$dirty{$f} = 1;
		}
		$DIRTY = 1;
	}
	if($CITE_CHANGE) {
		do_timeline_and_network();
		$DIRTY = 1;
		for my $k (keys %dirty) { $dirty{$k} = 1 }
		$DIRTY_CHARTS = 1;
	} elsif($CR_CHANGE) {
		do_network(1000);
		$DIRTY = 1 if $DO_OR;
		$dirty{or} = $dirty{ml} = 1;
	} elsif($SCORE_CHANGE) {
		calc_totals();
		calc_over_t();
	}
	$NEEDSAVE ||= $DIRTY;
	return node2html($a->{rid}, 1, $msg);
	return "<pre>". Dumper($a) ."</pre>";
}

sub add_live_menu {
	my $sr = shift;
	my $ent = shift||'';
	my %sets = qw(wd 1 or 1 in 1 i2 1 co 1);
	my $ent4sets = $sets{$ent} ? $ent : '';
	my $helpurl = $NODES ? $help{$ent}||'whatishistcite.html' : 'introduction.html';

	my $HI_COLOR = '#08246b';
	my $ment = ('tl' eq $ent) ? 'main' : $ent;
	my $ITEMS = 0;
	if('tl' eq $ent) {
		$ITEMS = @tl;
	} elsif('mark' eq $ent) {
		$ITEMS = $MARKS;
	} elsif('temp' eq $ent) {
		$ITEMS = (keys %{$hrt});
	} else {
		$ITEMS = @{$ari{$ent}} if $ent;
	}
	my $PI = ($main{$ment} or 'ml' eq $ment) ? $MAIN_PI : $AU_PI;
	my @g = keys %g;

	my $SAVE = '<li>';
	if(@tl && $NEEDSAVE) {
		my $msg = $FILENOW ? '' : 'NEW ';
		my $filenow = $FILENOW ? $FILENOW : "$title_file.hci";
		$msg .= "'$filenow'";
		$SAVE .= <<"";
<a href=# onclick="location.replace('/?cmd=savenow&url='+location.pathname+'&${\(time)}');return false" title=" Save changes to $msg"><b>Save</b><div></div></a>

	} else {
		my $filenow = $FILENOW ? $FILENOW : $title_file;
		$filenow ||= 'empty file';
		$SAVE .= qq(<a href="javascript:alert('There are no changes to save.')" title=" '$filenow' not changed" class="dimmed">Save<div></div></a>);
	}
	$SAVE .= '</li><li>';
	my $clas = '';
	#need to take care of saved file menu status change
	my $url = "href='/?cmd=savemain'";
	unless(@tl) {
		$clas = 'class="dimmed"';
		$url = '';
	}
	$SAVE .= qq(<a $url title=" Save under a different name" $clas>Save as...<div></div></a></li>);
	if(@tl) {
		$url = qq(href=# OnClick="window.open('/savehtmlestimate','esti',$win_opts)");
	} # used for HTML pres below

	my %edit = qw(au 1 in 1 i2 1 or 1 ml 1);
	my $File = $IE7 ? qq(<span onmouseover="getElementById('Exports').style.display='none';getElementById('Exports').style.display=''">File</span>) : 'File';
	my $selIE6 = '';
	my $selfunIE6 = '';
	if($IE6 && ($m_mark_menu_show || $m_go_show)) {
		$selIE6 = q(onmouseover="clearTimeout(tsid);hide_selects()" onmouseout="tsid=setTimeout('show_selects()',500)");
		$selfunIE6 = <<"";
var tsid;
function hide_selects() {
	if(document.getElementById('selectsMT'))
		document.getElementById('selectsMT').style.visibility = 'hidden';
	if(document.getElementById('selectGT'))
		document.getElementById('selectGT').style.visibility = 'hidden';
}
function show_selects() {
	if(document.getElementById('selectsMT'))
		document.getElementById('selectsMT').style.visibility = 'visible';
	if(document.getElementById('selectGT'))
		document.getElementById('selectGT').style.visibility = 'visible';
}

	}

	# absolute right position does not work in ie6

	$$sr .= <<"";
<STYLE>
div#menu {
	position: fixed; top: 0; left: 0;
	margin: 0; width: 100%;
	behavior: url(/csshover2.htc);	/* MSIE6 */
	background: $MENU_COLOR; border-bottom: solid black 1px;
	font: 12px Verdana; cursor: default;
	z-index: 10;
}
div#menu ul {
	margin: 0; padding: 0; background: $MENU_COLOR;
/*  border: 1px solid #fff; border-width: 0 1px; */
}
div#menu li {
	position: relative; list-style: none; margin: 0;
	float: left; line-height: 1em;
	display: block; padding: 0.25em 0.5em 0.25em 1em;
	white-space: nowrap;
	z-index: 10;	/* thus sez MSIE6 */
}
div#menu div#logo {
	text-align: right;
}
div#menu span#logo {
	padding: 0 1em; background: #eee;
	font: 17px Helvetica bold;
}
div#menu ul.level2 {
	border: outset #222 1px;
}
div#menu ul.level2#AnalysesBox {
	width: 16.5em;
}
div#menu ul.level2#view {
	width: 9em;
}
div#menu ul.level2#ToolsBox {
	width: 12em;
}
div#menu li:hover {
	background-color: $HI_COLOR; color: #fff;
}
div#menu ul.level2 li {
	width: 100%; padding: 0; margin: 0;
}
div#menu ul.level2 li a div {
	text-align: right; display: inline; position: absolute; right: 10px;
}
div#menu ul.level2 li.hr {
	line-height: 4px; height: 4px;
}
div#menu ul.level2 li.hr:hover {
	background: $MENU_COLOR;
}
div#menu ul.level2 li.hr div.hr {
	background-color:#555;
	line-height: 1px; height: 1px;
	margin: 0; padding: 0; border: 0; margin-top: 1px;
/*	border: groove #ddd; border-width: 0; border-top-width: 1px; */
	position: absolute; left: 2%;
	width: 96%; font-size: 1px;
}
div#menu li.submenu {
	background: url(/submenu.gif) 95% 50% no-repeat;
}
div#menu li.submenu a:hover {
	background: url(/submenu_i.gif) 95% 50% no-repeat;
	background-color: $HI_COLOR; color: #fff;
}
div#menu .radio_vu,
div#menu .radio_vu:hover {
	background: url(/radio.gif) 2% 50% no-repeat;
	background-color: $MENU_COLOR; color: #000;
	font-weight: bold;
}
div#menu .check {
	background: url(/check.gif) 2% 50% no-repeat;
}
div#menu .check:hover {
	background: url(/check_i.gif) 2% 50% no-repeat;
	background-color: $HI_COLOR;
}
div#menu ul.level3 a:hover,
div#menu ul.level3v a:hover {
	background: $HI_COLOR;
}
div#menu li a {
	text-decoration: none; color: #000;
	display: block; padding: 0.25em 0.5em 0.25em 1em;
	cursor: default;
}
div#menu>ul a {
	width: auto;
}
div#menu li a.current,
div#menu li a.current:hover {
	font-weight: bold; color: #000; background: $MENU_COLOR;
}
div#menu li a.dimmed, .dimmed,
div#menu li a.dimmed:hover {
	color: $DIM_COLOR; background: $MENU_COLOR;
}
div#menu li a:hover {
	color: white; background: $HI_COLOR;
}
div#menu ul ul {
	position: absolute; width: 11em; display: none;
}
div#menu ul.level1 li:hover ul.level2,
div#menu ul.level1 li.submenu:hover ul.level2,
div#menu ul.level2 li.submenu:hover ul.level3v,
div#menu ul.level2 li.submenu:hover ul.level3 {
	display: block;
}
div#menu ul.level2 {
	top: 1.5em; left: 0;
	border-top: outset #222 3px;
}
div#menu ul.level3 {
	top: -1px; left: 11em; width: 12em;
	border: outset #222 1px;
}
div#menu ul.level3v {
	top: -1px; left: 9em; width: 8em;
	border: outset #222 1px;
}
br#menu_pm {
	line-height: ${\($LIVE && !$IE6 ? '22px' : 0)};
}
div.ephemeral, div.index {
	border: solid $MENU_COLOR 1px; padding: 2px 2px 3px 2px;
	font: 12px Verdana; position: relative; margin: 4px 0;
	line-height: 17px; z-index: 1;
}
div.ephemeral td {
	font: 12px Verdana;
}
div.ephemeral input,select {
	font: 10px Verdana;
}
/* div.ephemeral a, div.index a {
	text-decoration: none;
}*/
span.x {
	position: absolute; top: 0; right: 0;  /*${\($ie ? '1px' : 0)};*/
	background: $MENU_COLOR; padding: 2px;
	border: 0; font-size: 10px; line-height: 10px;
	font-weight: normal;
	text-decoration: none;
}
span.x a, a span.x {
	color: #000; cursor: default;
	text-decoration: none;
}
span.x a:hover, span.x:hover  {
	font-weight: bold;
}
</STYLE>
<SCRIPT>
var tid;
function hold_on (id) {
	clearTimeout(tid);
	document.getElementById(id).style.display = 'block';
	tid = setTimeout("document.getElementById('"+id+"').style.display='none';document.getElementById('"+id+"').style.display='';", 500);
}
var id = ['File', 'AnalysesBox', 'view', 'ToolsBox', 'HelpBox'];
function clear_others() {
	for(var i=0; i<id.length; i++) {
		document.getElementById(id[i]).style.display = 'none';
		document.getElementById(id[i]).style.display = '';
	}
}
$selfunIE6
</SCRIPT>
<div id="menu" class="nonprn">
<ul class="level1">
	<li $selIE6><span onmouseover=clear_others()>$File</span><ul class="level2" id="File" onmouseover=clearTimeout(tid) onmouseout=hold_on('File')>
		<li><a href=# ${\($ent ? 'onClick=af_show()':'class=dimmed')} title=" Load bibliography data">Add File...<div>Alt+F</div></a></li>
		<li><a href=# ${\($ent ? q(OnClick="window.open('/node/edit-.html','edit','width=770,height=570,resizable=yes,scrollbars=yes')"):'class=dimmed')} title=" Create a new record">New record...<div></div></a></li>
		<li><a href='/?cmd=close' ${\(QCONF())} title=" Close collection">Close<div></div></a></li>
		<li class=hr><div class=hr></div></li>
		$SAVE
		<li class="submenu"><a href=#>Export<div></div></a><ul class="level3" id="Exports">
			<li><a href=${\($ITEMS
			? ('temp' eq $ent or 'mark' eq $ent)
					? qq(/?cmd=save$ent title=" Save current bibliography to a separate file (HistCite format)")
				: ('tl' eq $ent)
					? '/?cmd=savemain title=" Save full bibliography to a separate file (HistCite format)"'
				: '# class=dimmed title=" Available in Record lists"'
			: '# class=dimmed title=" Save bibliography to a separate file (HistCite format)"')}>Records...<div></div></a></li>
<!--			<li><a href=${\(($modcsv{$ent} && $ITEMS) ? qq(/?cmd=savecsv&li=$ent title="Save this list in CSV format") : '# class=dimmed title="Available in appropriate Analytical lists"')}>As CSV... <div></div></a></li> -->
			<li><a href=${\($ITEMS ? qq(/?cmd=savecsv&li=$ent) : '# class=dimmed')} title=" Save this list in CSV format">As CSV... <div></div></a></li>
			<li class=hr><div class=hr></div></li>
			<li><a href=# ${\(@tl>0 ? qq(OnClick="window.open('/savehtmlestimate','esti',$win_opts)") : 'class=dimmed')} title=" Generate HTML presentation for Web publishing">HTML presentation<div></div></a></li>
		</ul></li>
		<li class=hr><div class=hr></div></li>
		<li><a href=# ${\($ent ? q(OnClick="window.open('/properties','settings','width=490,height=480,resizable=yes,scrollbars=yes,status=yes')"):'class=dimmed')} title=" Collection properties">Properties...<div></div></a></li>
		<li class=hr><div class=hr></div></li>
		<li><a href=javascript:print()>Print...<div>Ctrl+P</div></a></li>
		<li class=hr><div class=hr></div></li>
		<li><a href='/?cmd=exit' ${\(QCONF())} title=" Exit the program">Quit<div>Alt+Q</div></a></li>
	</ul></li>
	<li $selIE6><span onmouseover=clear_others()>Analyses</span><ul class="level2" id="AnalysesBox" onmouseover=clearTimeout(tid) onmouseout=hold_on('AnalysesBox')>
		${\(analyses_list($ent))}
	</ul>
	</li>
	<li><span onmouseover=clear_others()>View</span><ul class="level2" id="view" onmouseover=clearTimeout(tid) onmouseout=hold_on('view')>
		<li><a href=${\($CUST ? '# class="dimmed"'
			: 'base' eq $VIEW && !$CUST ? '# class=radio_vu' : '"?VIEW=base" title=" Switch to Standard view"')}>Standard</a></li>
		<li><a href=${\($CUST ? '# class="dimmed"'
			: 'bibl' eq $VIEW && !$CUST ? '# class=radio_vu' : '"?VIEW=bibl" title=" Switch to Bibliometric view"')}>Bibliometric<div></div></a></li>
		<li><a href=${\($CUST ? '# class="dimmed"'
			: 'cust' eq $VIEW && !$CUST ? '# class=radio_vu' : '"?VIEW=cust" title=" Switch to Custom view"')}>Custom<div></div></a>
		<li class=hr><div class=hr></div></li>
		<li><a href=${\($CUST ? '# style="font-weight:bold"'
			: $NODES?'"/customize" title=" Select parameters for Custom view"':'# title=" Available when data is loaded" class="dimmed"')}>Customize<div></div></a></li>
	</ul></li>

	$$sr .= <<"";
	<li $selIE6><span onmouseover=clear_others()>Tools</span><ul class="level2" id="ToolsBox" onmouseover=clearTimeout(tid) onmouseout=hold_on('ToolsBox')>
		<li><a href=# ${\(@tl>0 ? qq(OnClick="window.open('/graph/GraphMaker','graph',$win_opts)") : 'class=dimmed')} title=" Make Historiographs">Graph Maker...<div></div></a></li>
		<li><a href=# ${\(@g>0 ? qq(OnClick="window.open('/graph/list.html','graph',$win_opts)" title=" List saved Historiographs") : 'class=dimmed title=" There are no saved Historiographs"')}>Historiographs<div></div></a></li> <li class=hr><div class=hr></div></li> <li><a href=${\(@tl>0 ? ('temp' eq $ent
				? ($m_search_form_show
					? '?showsf=OFF class=check title=" Hide search form"'
					: '?showsf=ON title=" Show search form"')
				: ('mark' eq $ent and $MARKS)
					? '/searchmarks/ title=" Show search form"'
					: '/search/ title=" New search"')
			: '# class=dimmed')}>Search<div></div></a></li>
		<li><a href=${\(($ITEMS > $PI) ? ($m_go_show ? '?showgo=OFF class=check title=" Hide Move to"' : '?showgo=ON title=" Show Move to"') : '# class=dimmed title=" Move to is available in longer lists"')}>Move to<div></div></a></li>
		<li><a href=${\($ITEMS ? ($m_mark_menu_show ? '?showmm=OFF class=check title=" Hide mark & tag menu"' : '?showmm=ON title=" Show mark & tag menu"') : '# class=dimmed')}>Mark & Tag<div>Alt+M</div></a></li>
		<li><a href=${\($ITEMS ? ($edit{$ent} ? ($m_edit_menu_show ? '?showem=OFF class=check title=" Hide edit menu"' : '?showem=ON title=" Show edit menu"') : '# class=dimmed title=" Edit is available in Authors, Cited References, Institution lists"') : '# class=dimmed')}>Edit<div></div></a></li>
		<li class=hr><div class=hr></div></li>
		<li><a href=${\($m_ai_show ? '"?showai=OFF" class=check title=" Hide Analyses index"' : '"?showai=ON" title=" Show Analyses index on the page"')}>Analyses index<div></div></a></li>
		<li class=hr><div class=hr></div></li>
		<li><a href=# OnClick="window.open('/settings/$ent4sets','settings','width=490,height=480,resizable=yes,scrollbars=yes,status=yes')" title=" Change settings">Settings...<div>Alt+S</div></a></li>
		<li><a href=# OnClick="window.open('/?cmd=viewlog','log',$win_opts)" title=" View session log">Log...<div></div></a></li>
		${\($DETAIL ? qq(<li><a href=# OnClick="window.open('/?cmd=viewdup','dup',$win_opts)" $clas title="Review discarded duplicate records">Dups<div></div></a></li>) : '')}
	</ul></li>
	<li><span onmouseover=clear_others()>Help</span><ul class="level2" id="HelpBox" onmouseover=clearTimeout(tid) onmouseout=hold_on('HelpBox')>
		<li><a href=# OnClick="gethelp('/?help=$helpurl')">Help<div></div></a></li>
		<li><a href=# OnClick="gethelp('/?help=glossary.html')" title=" Glossary of acronyms">Glossary<div></div></a></li>
		<li><a href=javascript:tip_show()>Tip of the Day<div></div></a></li>
		<li class=hr><div class=hr></div></li>
		<li><a href=# OnClick="window.open('http://www.histcite.com/','hc','resizable=yes,menubar=yes,toolbar=yes,location=yes,scrollbars=yes')" title=" Go to HistCite's Web site">Web Site<div></div></a></li>
		<li><a href=javascript:about()>About HistCite<div></div></a></li>
	</ul></li>
</ul>
	<div id=logo><span id=logo><a title=" Bibliometric Analysis and Visualization Software " style="color:#000;text-decoration:none;">HistCite&trade;</a></span></div>
</div>

	add_live_keys($sr, $ITEMS, $ent4sets);
	add_toggle_script($sr);
}

sub add_live_keys {
	my($sr, $ITEMS, $ent4sets) = @_;
	my $on = QCONF();
	my $click = $ie ? 'click()' : '';
	$on = qq(onfocus="$click") unless $on;
	#blur, click, empty a - IE hacks
	$$sr .= <<"";
<style>.hid { color:#fff }</style>
<span class=hid>
<a href=#></a><a href=#></a><a href=#></a>
<a href="javascript:af_show();" onfocus="blur();$click" accesskey="f"></a>
<a href=${\($ITEMS ? ($m_mark_menu_show ? '?showmm=OFF' : '?showmm=ON') : '#')} onfocus="blur();$click" accesskey="m"></a>
<a href=# OnClick="window.open('/settings/$ent4sets','settings','width=490,height=480,resizable=yes,scrollbars=yes,status=yes')" onfocus="blur();$click" accesskey="s"></a>
<a href='/?cmd=exit' onfocus="blur();$click" $on accesskey="q"></a>
</span>

}

sub analyses_list {
	my $what = shift||'';
	my $pubs = $LIVE ? '' : '-pubs';
	my %name = (qw(tl Records mark Marks au Authors so Journals or),
		'Cited References', qw(wd Words tg Tags));
	my %count = (tl => 0+@tl, mark => $MARKS, au => 0+@aui, so => 0+@jni,
		or => 0+@ori, wd => 0+@wdi, tg => 0+@tgi );
	my $list = '';
	$list = 'list/' if 'tl' eq $what;
	$list = '../list/' if 'mark' eq $what or 'temp' eq $what;
	my %url = qw(mark /mark/index.html);
	$url{tl} = $LIVE ? '/' : '../index-tl.html';
	my @fi;
	for my $fi qw(tl mark au so) {
		next if 'mark' eq $fi and !$MARKS;
		push @fi, $fi;
	}
	push @fi, 'or' if $DO_OR;
	push @fi, 'wd' if $DO_WD;
	push @fi, 'tg' if $TAGS > 1 or ($TAGS == 1 && not defined $tg{Other});

	my $o = '';
	$o .= <<"" if $DIRTY;
<li><a href=# onclick="location.replace('update_modules?url='+location.pathname+'&${\(time)}');return false" title="Update analysis lists to reflect changes"><font color=red>Update lists</font></a></li>
<li class=hr><div class=hr></div></li>

	for my $fi (@fi) {
		$o .= '<li class=hr><div class=hr></div></li>' if 'au' eq $fi;
		$o .= '<li><a';
		if($what eq $fi) {
			$o .= ' class="current"';
		} else {
			my $url = $url{$fi}; $url ||= "$list$fi$pubs.html";
			$o .= " href=$url";
		}
		$o .= ">$name{$fi}";
		$o .= "<div>$count{$fi}</div></a></li>";
	}

	for my $fi qw(py dt la in i2 co) {
		my $url = $url{$fi}; $url ||= "$list$fi$pubs.html";
		$o .= '<li><a';
		$o .= " href=$url" unless 'py' eq $fi and 0 > $#tl;
		if($what eq $fi) {
			$o .= ' class="current"';
		} else {
			$o .= ' class="dimmed"' if 'py' eq $fi and 0 > $#tl;
		}
		my $recs = @{$ari{$fi}}||0;
		$o .= " title=' $items{$fi}: $recs '>";
		$o .= 'py' eq $fi ? 'Yearly output' : $f_ful{$fi};
		$o .= '<div></div></a></li>';	# to stretch <a> in MSIE
	}
#hold	$o .= <<"";
#<li class=hr><div class=hr></div></li>
#<li><a href=${\(@mli > 0 ? ('ml' eq $what ? '# class="current"' : '/list/ml.html') : '# class=dimmed')} title="Review additional citation links">Missing links<div>${\(scalar @mli)}</div></a></li>

	return $o;
}

sub QCONF {
	return ($NEEDSAVE && $NODES ? "onclick=\"return (confirm('There are unsaved changes.\\n\\nClick OK to discard them,\\nCancel to go back.'))\"" : '');
}

sub QCONF4 {
	return ($NEEDSAVE && $NODES ? "alert=('You are closing the browser, but\\nthere are unsaved changes.\\n\\n')" : '');
}

sub add_common_style {
	my $sr = shift;
	$$sr .= <<"";
<STYLE>
body {
	margin: 2px 10px; padding: 0;
	background: $BG_COLOR;
}
body, td, th {
	font-size: ${FONT_SIZE}pt; font-family: Verdana;
}
input, select, textarea {
	font-size: ${FONT_SIZE}px; font-family: Verdana;
}
.ui {
	font-size: 10pt; font-family: Verdana;
}
.ui input, .ui select, .ui textarea {
	font-size: 10px; font-family: Verdana;
}
.ci_title {
	font-size: ${\($FONT_SIZE-2)}pt; font-weight: bold;
}
.ci_il {
	color: black; text-decoration: none;	/* msie6 ! inherit */
}
.helpa { text-decoration: none;
	cursor: help;
}
.helpt { background: $HELPTIP_COLOR; padding: 4px;
}
.nu { text-decoration: none; 
}
.sc, .sc a { color: $SORT_COLOR }
.fnd { background-color: $FOUND_COLOR;
	padding: 0 3px 2px 2px;
}
td div.fndCR {
	padding-left: 2em;
//	text-indent: -2em;
}
.odd { background-color: $TR_ODD_COLOR }
.evn { background-color: $TR_EVN_COLOR }
div.odd { padding: 5px; margin-bottom: 2px }
div.evn { padding: 5px; margin-bottom: 2px }
.yr { padding: 0; font-weight: bold }
.ank:hover { cursor: pointer; text-decoration: none; color: inherit; }
a {
	text-decoration: none;
}
a:hover, a:hover .sc {
	text-decoration: underline; color: blue;
}
.scr:hover, td a.scr:hover { color:#000; text-decoration:none; } /* FF td */
\@media print {
	.nonprn, .ephemeral, .x, .ui { display: none; }
	.index { border: solid #fff 0; }
	body { font-size: 10pt; }
	td, th { font-size: 10pt; }
	.ci_title { font-size: 8pt; }
}
</STYLE>

}

sub add_ui_style {
	my $sr = shift;
	$$sr .= <<"";
<STYLE>
body {
	margin: 2px 10px; padding: 0;
	background: $BG_COLOR;
}
body, td, th {
	font-size: 10pt; font-family: Verdana;
}
input, select, textarea {
	font-size: 10px; font-family: Verdana;
}
</STYLE>

}

sub add_body_script {
	my $sr = shift;
	my $ui = shift||'';
	my $d = shift;
	$d = $d ? "'$d'" : 'd';		## deprecated ?
	$$sr .= <<"";
<BODY VLINK=blue OnLoad="focus()">
<SCRIPT>function opeNod (a) { opener.top.opeNod(a); }
function opeLod (d, a) { opener.top.opeLod($d, a); }
function na(){}
document.onkeydown = function (e) { e = e ? e : event ? event : null;
	if(e) if(e.keyCode==27) close();
}
</SCRIPT>

	if($ui) {
		add_ui_style($sr);
	} else {
		add_common_style($sr);
	}
}

sub add_body_style_main {
	my $sr = shift;
	my $load = shift||'focus()';
	if($Start && $TipOnStart) {
		#$load .= ';tip_show();';
	}
	my $root = $LIVE ? "'http://$host:$port/';" :
		q(location.href; root = root.replace(/index.*/, ''); root = root.replace(/list.*/, ''););
	$$sr .= <<"";
<BODY VLINK=blue OnLoad="$load">

	add_common_style($sr);
	$$sr .= <<"";
<SCRIPT>
var root=$root
function about () { window.open(root+'about.html','about','width=440,height=370,resizable=yes,scrollbars=yes') }
	$$helpjs
</SCRIPT>
${\(tipbox)}
${\(addfile())}

}

sub add_close_link {
	my $live = '';
	$live = "?${\(time)}" if $LIVE;
	${$_[0]} .= <<"";
&nbsp;<a href="javascript:if(opener) opener.location.replace(opener.location.pathname + '$live');close()" style=text-decoration:none title='Close this window'>Close</a>

}

sub add_js_switch {
	my($sr, $wich, $str) = @_;
	my $var_str = $str;	$var_str =~ y/ /_/;
	my $switch = eval "\$m_${var_str}_show ? 'OFF' : 'ON'";
	my $act = eval "\$m_${var_str}_show ? 'Hide' : 'Show'";
	$act .= ' <span id=nodecnt>...</span> ' if 'icr' eq $wich;
	$$sr .= <<"";
 <a href="javascript:turn_$wich('$switch')" style=text-decoration:none>$act $str</a>
<SCRIPT>function turn_$wich (s) {
	document.t.show$wich.value = s;
	document.t.submit();
}</SCRIPT>

}

sub add_mark_form {
#<INPUT type=radio name=scope value=page ${\('page' eq $m_sets_main_scope ? 'CHECKED' : '')}> all records on this page<br>
	my($sr, $ent) = @_;
	my $border_top = $ie ? 'border-top:solid #000 3px;' : '';
	$$sr .= <<"";
<style>
div.ephemeral td { line-height: 20px; border-top: solid #000 1px; }
</style>
<div class="ephemeral" style="background:$MENU_COLOR;padding:0;border:solid #000 1px;$border_top">
<b style="margin:4px;">Marking and Tagging Tool</b>
<span class="x" style="top:1px;right:2px;"><a href="?showmm=OFF" title="Hide this tool">X</a></span>
<a href=javascript:gethelp('/?help=markandtag.html') class=helpa style="color:#000">
<span class="x" style="top:1px;right:20px;">Help</span></a>
<TABLE width=100% border=0 cellspacing=0 cellpadding=2 style="margin:0;border-collapse:collapse;">
<TR valign=top style="border-top:solid #000 1px;"><TD nowrap>
Set Criteria:<br>&nbsp; &nbsp;
<INPUT type=radio name=scope value=full_list ${\('full_list' eq $m_sets_main_scope ? 'CHECKED' : '')} ${\('main' eq $ent ? '' : 'DISABLED')}> <span ${\('main' eq $ent ? '' : 'class=dimmed')}>Select all records from current list</span>
<br>&nbsp; &nbsp;
<INPUT type=radio name=scope value=all_marks ${\('all_marks' eq $m_sets_main_scope ? 'CHECKED' : '')} ${\($MARKS ? '' : 'DISABLED')}> <span ${\($MARKS ? '' : 'class=dimmed')}>Select all marked records</span>
<br>&nbsp; &nbsp;
<INPUT type=radio name=scope value=range ${\('range' eq $m_sets_main_scope ? 'CHECKED' : '')}>
Select records with <br>&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;<span id='selectsMT'>
<SELECT name=field OnFocus="document.t.scope[2].checked=true;" OnChange="document.t.val1.focus();">
${\( do {
	my @sel = ('#', qw(py lcs tc gcs na lcr ncr lcst gcst lcsb lcse));
	my $o;
	for my $v (@sel) {
		next unless $view{$ent}{$VIEW}{$v} or '#' eq $v;
		$o .= "<OPTION value=$v ". ($v eq $m_sets_main_field ? 'SELECTED' : '') .">$sel{$v}";
	}
	$o .= '</SELECT>';
	$o .= qq(<SELECT name=sign OnFocus="document.t.scope[2].checked=true;" OnChange="document.t.val2.disabled = 'range' == this.value ? false : true;document.t.val1.focus();">);
	my %sel = ('ne', 'Not Equal', qw(eq Equal gt Greater lt Less range Range));
	@sel = qw(eq ne gt lt range);
	for my $v (@sel) {
		$o .= "<OPTION value=$v ". ($v eq $m_sets_main_sign ? 'SELECTED' : '') .">$sel{$v}";
	}
	$o .= '</SELECT>';
	$o;
})}</span>
<INPUT type=text name=val1 size=5 OnFocus="t.scope[2].checked=true;"> - 
<INPUT type=text name=val2 size=5 OnFocus="t.scope[2].checked=true;">
<br>&nbsp; &nbsp;
<INPUT type=radio name=scope value=checks_on_page ${\('checks_on_page' eq $m_sets_main_scope ? 'CHECKED' : '')}>Select records checked on this page
<br>&nbsp; &nbsp;<span style="visibility:hidden;"><input type=radio></span>
${\( alter_checks_links() )}
<TD width=10><TD style="border-left:solid #000 1px;">
Set Scope:<br>&nbsp; &nbsp;
<INPUT type=checkbox name=nodes ${\($m_sets_main_nodes ? 'CHECKED' : '')}> Selected records only<br>&nbsp; &nbsp;
<INPUT type=checkbox name=cited ${\($m_sets_main_cited ? 'CHECKED' : '')}> Records citing selected records<br>&nbsp; &nbsp;
<INPUT type=checkbox name=cites ${\($m_sets_main_cites ? 'CHECKED' : '')}> Records cited by selected records<br>
</TD>
<TD width=10>&nbsp;<TD align=left nowrap style="border-left:solid #000 1px;">
Take Action:<br>
<INPUT class=submit type=submit name=actin value=Mark> &nbsp;&nbsp;
<INPUT type=submit name=actin value=Unmark ${\($MARKS ? '' : 'DISABLED')}> &nbsp;&nbsp;
<INPUT type=submit name=actin value=Delete>
<br><b>OR</b><br>
Tag: <INPUT type=text name=tag size=6><br>
Description:<br>
<INPUT type=text name=tagdesc size=32><br>
<INPUT type=submit name=tagset value=Tag>
<INPUT type=submit name=tagset value=Untag>
<INPUT type=submit name=tagset value="Remove All Tags" style="width:120px;">
</TD>
</TABLE>
<SCRIPT>
document.t.val2.disabled = 'range' == document.t.sign.value ? false : true;
</SCRIPT></div>

}

sub alter_checks_links {
	my $o = <<"";
<a id="cl" href=javascript:clear_checks() style=text-decoration:none title='Clear check boxes on this page'>Clear checks</a>&nbsp;&nbsp;&nbsp;&nbsp;
<a id="ci" href=javascript:reverse_checks() style=text-decoration:none title='Invert selection of check boxes on this page'>Invert checks</a>

	return $o;
}

sub add_checks_script_functions {
	${$_[0]} .= <<"";
<SCRIPT>
var n = document.t.node;
if(!n || !n.length) {
	var cl = document.getElementById('cl');
	var ci = document.getElementById('ci');
	if(cl) {
		cl.style.display = 'none';
		ci.style.display = 'none';
	}
}
function clear_checks () {
	for(var i=0; i<n.length; i++) {
		n[i].checked = false;
	}
}
function reverse_checks () {
	for(var i=0; i<n.length; i++) {
		n[i].checked = !n[i].checked;
	}
}
</SCRIPT>

}

sub add_toggle_script {
	${$_[0]} .= <<"";
<SCRIPT>
function toggle (id) {
  var eid = document.getElementById(id);
  var eid2 = document.getElementById(id + '2');
  var mid = document.getElementById('m' + id);
  var lid = document.getElementById('l' + id);
  if(eid.style.display == 'none') {
    eid.style.display = 'block';
		if(eid2) eid2.style.display = 'block';
    mid.style.display = 'none';
    lid.style.display = '';
  } else {
    eid.style.display = 'none';
		if(eid2) eid2.style.display = 'none';
    mid.style.display = '';
    lid.style.display = 'none';
  }
}
</SCRIPT>

}

sub add_goto_form {
	my($sr, $ent, $page, $hr, $advance, $found) = @_;
	$sel{name} = 'wd' eq $ent ? 'Word'
		: defined $f_ful{$ent} ? $f_ful{$ent} : 'Name';
	my $pent = $main{$ent} ? 'index' : "$ent";
	my $goto_value = $m_sets_main_goto_value{$ent}||'';
	my $goto_data = $m_sets_main_goto_data{$ent}||('or' eq $ent ? 'ca' : 'name');
	my $size = length($goto_value);
	$size = 10 if 10 > $size;
	$size += 40 > $size ? 8 : 16;

	$$sr .= <<"";
<style>#go { position: relative;
	border: 1px solid #000; font: 12px Verdana;
	background: #fff; margin-bottom: 0; padding: 4px; width: 99%; }
#go input, #go select {
	font: 10px Verdana;
}
</style>
<div class="nonprn" id="go">
<span class="x"><a href="?showgo=OFF" title="Hide this tool">X</a></span>
Move to: <span id='selectGT'><SELECT name=data OnChange="document.t.valuem.focus();">
${\( do {
	my @sel = ('#', qw(tl py ca cy au1 so name pubs lcs tc gcs lcr ncr na lcst gcst lcsb lcse));
	my $en = ('mark' eq $ent or 'temp' eq $ent) ? 'main' : $ent;
	my $o = '';
	for my $v (@sel) {
		next if 'gcs' eq $v and 'main' eq $en;
		next unless $view{$en}{$VIEW}{$v} or '#' eq $v
			or ('main' eq $en and 'py' eq $v);
		$o .= "<OPTION value=$v ". ($v eq $goto_data ? 'SELECTED' : '') .">$sel{$v}";
	}
	$o .= '</SELECT></span>';
})}
<INPUT type=text name=valuem size=$size value="$goto_value">
<INPUT type=submit name=moveto value=Go OnClick="if('#'!=document.t.data.value){document.t.action='$pent-'+document.t.data.value+'.html'}else{document.t.action='$pent.html'}document.t.submit();">
&nbsp;<a href="javascript:clear_valuem()" style=text-decoration:none>Clear</a>
<SCRIPT>
function clear_valuem () {
	document.t.valuem.value = '';
	document.t.valuem.focus();
}
</SCRIPT>

	my $what = $goto_data;
	if($advance and not $found) {
		$$sr .= ' &nbsp; not found';
	}
	$$sr .= '</div>';
	$$sr .= <<"";
<script>
</script>

}

sub add_edit_form {
	my($sr, $ent) = @_;
	my $newedit_size = 'or' eq $ent ? 65 : 42;
	$$sr .= <<"";
<div class="ephemeral" style="background:$MENU_COLOR;">
${\($TL_MODIFIED ? 'This tool will be available after analyses lists are updated with new records.<div class="dimmed">' : '')}
<span class="x"><a href="?showem=OFF" title="Hide edit menu">X</a></span>
Check items below to replace with: <INPUT type=text name=newedit size=$newedit_size ${\($TL_MODIFIED ? 'DISABLED' : '')}>
<INPUT type=hidden name=editnow value=0>&nbsp;
${\($TL_MODIFIED ? '<font color=blue>Proceed</font>' : '<a href="javascript:send_edit()">Proceed</a>')}
<a href=javascript:toggle('edith') class=helpa style="color:#000">
<span class="x" id=medith style="top:0;right:14px;">?</span><span class="x" id=ledith style="top:0;right:14px;display:none">_</span></a><br>
<INPUT type=checkbox name=defer_net ${\($TL_MODIFIED ? 'DISABLED' : ($m_defer_net ? 'CHECKED' : ''))}>
Defer network update
<div id=edith class=helpt style="display:none;">
Select the terms for editing and enter the replacement string.
Then click <font color=blue>Proceed</font>.  Check 'Defer network update'
to delay citation network changes (helpful when planning many changes
to a large collection).
</div><SCRIPT>
function send_edit () {
	var v = document.t.nval;
	var s = '';
	if(n.length || n) {
		if(n.length) {
			for(var i=0; i<n.length; i++) {
				if(n[i].checked)
					s += v[i].value + "\\n";
			}
		} else {
			if(n.checked)
				s += v.value + "\\n";
		}
		if(''==s) {
			alert('No terms selected.');
		} else if(''==document.t.newedit.value) {
			alert('No replacement string'); document.t.newedit.focus();
		} else {
			if(confirm("The following selected for replacement:\\n" +s +"\\nwith: " +document.t.newedit.value)) {
				document.t.editnow.value = 1;
				document.t.submit();
			}
		}
	}
}
function check_newedit () {
	var v = document.t.nval;
	var val;
	var tot_checked = 0;
	if(n.length || n) {
		if(n.length) {
			for(var i=0; i<n.length; i++) {
				if(n[i].checked) {
					if('' == document.t.newedit.value) {
						document.t.newedit.value = v[i].value.replace(/^\\d+\\. +/, '');
					}
					tot_checked++;
				}
			}
		} else {
			if(n.checked) {
				if('' == document.t.newedit.value)
					document.t.newedit.value = v.value.replace(/^\\d+\\. +/, '');
				tot_checked++;
			}
		}
		if(0 == tot_checked)
			document.t.newedit.value = '';
	}
}
</SCRIPT>
${\($TL_MODIFIED ? '</div>' : '')}
</div>

#var n = document.t.node; defined in add_checks_script_functions
}

sub add_search_form {
	my $sr = shift;
	my $temp = keys %$hrt;
	$$sr .= <<"";
<div class="ephemeral">
<span class="x"><a href="?showsf=OFF" title="Hide search form">X</a></span>
<table width=100% border=0><tr valign=top><td align=left>
Author:<br>
<INPUT type=text name=author size=16 value="$s_search_author">
<p>Journal:<br>
<INPUT type=text name=source size=42 value="$s_search_source">
<p>Word (in ${\(inf_wd())}):<br>
<INPUT type=text name=tiword size=36 value="$s_search_tiword">
<p>Publication Year:<br>
<INPUT type=text name=pubyear size=10 value="$s_search_pubyear">
<p>
<INPUT type=submit name=search value="Search collection">
&nbsp;
<INPUT type=submit name=search value="Search within results" ${\($temp?'':'disabled')}>
</p>
<td align=left width=400><div style="border:solid #000 1px;padding:3px;margin-right:9px;">
Enter single terms in the search fields. Search does not support Boolean
operators. Use asterisk (*) for wild card.
<p>
Author Examples: Smith JN, Smith J*, Smith*
<p>
Journal Examples: NATURE, JOURNAL OF BIO*, *GENE*
<p>
Word: Do not use quote marks or spaces (if included in Word list, keywords may contain spaces).<br>Examples: PACIFIC, FISH*, *GENE*
<p>
Publication Year: Single year e.g. 1992.<br>Year Range e.g. 1989-1995
</div></table>
</div>

}

sub add_WoS_script {
	${$_[0]} .= <<"";
	<SCRIPT>
	var wos_gw = ${\($LIVE ? $WOS_GW : 0)};
	function doWoS(au, so, y) {
		switch(wos_gw) {
			case 0:
				this.document.SFX.target = "wos" + au + y;
				doSFX(au, so, y);
				break;
			case 1:
				this.document.WoK4.target = "wos" + au + y;
				doWoK4(au, so, y);
				break;
			case 2:
				this.document.toWoS.target = "wos" + au + y;
				if('' == this.document.toWoS.action) {
					alert('Please record the location of your Web of Science server\\nthrough the Tools > Settings menu.');
				} else {
					doWoK3(au, so, y);
				}
		}
	}
	function doSFX(au, so, y) {
		this.document.SFX.citedauthor.value = au;
		this.document.SFX.citedwork.value = so;
		this.document.SFX.citedyear.value = y;
		this.document.SFX.submit();
	}
	function doWoK4(au, so, y) {
		this.document.WoK4.elements[3].value = au;
		this.document.WoK4.elements[6].value = so;
		this.document.WoK4.elements[9].value = y;
		this.document.WoK4.submit();
	}
	</SCRIPT>
<FORM name=WoK4 action="${\($LIVE?$WOS_LOC4:'')}" METHOD=POST onSubmit="return false" target=WoS class=nonprn style="margin:0">
<input type="hidden" name="action" value="search" />
<input type="hidden" name="product" value="WOS" />
<input type="hidden" name="search_mode" value="CitedReferenceSearch" />
<INPUT TYPE=hidden NAME="value(input1)" VALUE="">
<INPUT TYPE=hidden NAME="value(select1)" VALUE="CA">
<INPUT TYPE=hidden NAME="value(bool_1_2)" VALUE="AND">
<INPUT TYPE=hidden NAME="value(input2)" VALUE="">
<INPUT TYPE=hidden NAME="value(select2)" VALUE="CW">
<INPUT TYPE=hidden NAME="value(bool_2_3)" VALUE="AND">
<INPUT TYPE=hidden NAME="value(input3)" VALUE="">
<INPUT TYPE=hidden NAME="value(select3)" VALUE="CY">
</FORM>
<FORM name=SFX action="http://gateway.isiknowledge.com/gateway/Gateway.cgi" METHOD=GET onSubmit="return false" target=WoS class=nonprn style="margin:0">
#<FORM name=SFX action="http://gateway.webofknowledge.com/gateway/Gateway.cgi" METHOD=GET onSubmit="return false" target=WoS class=nonprn style="margin:0">
<INPUT type=hidden name=GWVersion value=2>
<INPUT type=hidden name=SrcApp value=HistCite>
<INPUT type=hidden name=SrcAuth value=HistCite>
<INPUT type=hidden name=DestApp value=ALL_WOS>
<INPUT type=hidden name=ServiceName value=TransferToWoS>
<INPUT type=hidden name=DestLinkType value=CitedLookup>
<INPUT type=hidden name=Func value=Links>
<INPUT type=hidden name=citedauthor>
<INPUT type=hidden name=citedwork>
<INPUT type=hidden name=citedyear>
</FORM>

}

sub customize {
	my $what = shift;

	my $o = "$STD<HEAD><TITLE>HistCite - $$title</TITLE></HEAD>\n";

	add_body_style_main(\$o);
	local $CUST = 1;
	add_live_menu(\$o, 'tl');

	local $VIEW = 'cust';
	$o .= head_section('<b>Customize the Custom view</b>', 'main', '', $NODES, $what);

	$o .= '<div align=center style="margin:20px 0;font-size:10pt"><i>Select columns and record display style to create a Custom records view, then click <span style="font-style:normal;">[Customize!]</span>.</i></div>';

	$o .= '<FORM method=post style=margin:2px>';
	
	$o .= ${ main_table('main', $what, '', 0) };

	$o .= <<"";
<p>Citation record display: 
<INPUT type=radio name=rec value=full ${\('full' eq $REC_SHOW ? 'checked' : '')}>Full &nbsp;
<INPUT type=radio name=rec value=brief ${\('brief' eq $REC_SHOW ? 'checked' : '')}>Brief<br>
<p>
<b>Analyses lists</b><br>Display column Percent (of number of records):
<INPUT type=radio name=perc value=y ${\($view{au}{cust}{perc} ? 'checked' : '')}>Yes &nbsp;
<INPUT type=radio name=perc value=n ${\($view{au}{cust}{perc} ? '' : 'checked')}>No<br>
<p>
<b>Statistics</b><br>
Show h-index (LCS):
<INPUT type=radio name=hil value=y ${\($HIL_SHOW ? 'checked' : '')}>Yes &nbsp;
<INPUT type=radio name=hil value=n ${\($HIL_SHOW ? '' : 'checked')}>No<br>
Show h-index (LCSx):
<INPUT type=radio name=hix value=y ${\($HIX_SHOW ? 'checked' : '')}>Yes &nbsp;
<INPUT type=radio name=hix value=n ${\($HIX_SHOW ? '' : 'checked')}>No<br>
Show h-index (GCS):
<INPUT type=radio name=hig value=y ${\($HIG_SHOW ? 'checked' : '')}>Yes &nbsp;
<INPUT type=radio name=hig value=n ${\($HIG_SHOW ? '' : 'checked')}>No<br>
Show h-index (OCS):
<INPUT type=radio name=his value=y ${\($HIS_SHOW ? 'checked' : '')}>Yes &nbsp;
<INPUT type=radio name=his value=n ${\($HIS_SHOW ? '' : 'checked')}>No<br>
<p>
<div align=center><INPUT type=submit name=customize value="Customize!">
&nbsp; &nbsp;<INPUT type=submit name=cancel value="Cancel">
</div></FORM><p>
</BODY>

	return \$o;
}

sub cust_form {
	my $q = shift;

	my %cust = map {($_, 1)} $q->param('main');
	for my $f qw(lcs lcst lcsx tc gcst scs na lcr ncr lcsb lcse eb) {
		$view{main}{cust}{$f} = $cust{$f} ? 1 : 0;
	}
	$REC_SHOW = $q->param('rec')||'full';

	$view{au}{cust}{perc} = 'y' eq $q->param('perc') ? 1 : 0;

	$HIL_SHOW = 'y' eq $q->param('hil') ? 1 : 0;
	$HIX_SHOW = 'y' eq $q->param('hix') ? 1 : 0;
	$HIG_SHOW = 'y' eq $q->param('hig') ? 1 : 0;
	$HIS_SHOW = 'y' eq $q->param('his') ? 1 : 0;

	set_all_cust();
}

sub main2html {
	my $what = shift;
	my $final = shift;
	my $page = shift;
	my $advance = shift;
	my $found = shift;

	my $o = "$STD<HEAD><TITLE>HistCite - $$title</TITLE></HEAD>\n";

	add_body_style_main(\$o);
	add_live_menu(\$o, 'tl') if $LIVE;
	$Start = 0;

	my $nodes = $#tl + 1;

	$o .= head_section('<b>List of All Records</b>', 'main', '', $NODES, $what);
	$o .= new_table_menu('tl') if $m_ai_show or !$LIVE;

	unless($nodes) {
		$o .= '<div align=center style="margin:20px 0;font-size:10pt"><i>This collection is empty. Go to <span style="font-style:normal;">File -&gt; Add File...</span> to add records to this collection.</i></div>';
		$o .= '<div style="position:absolute;left:20%;font-size:18pt"><h1>HistCite&trade;</h1>Bibliometric Analysis and Visualization Software</div>';
		return \"$o</BODY>"
	}
	$o .= '<FORM method=post name=t style=margin:2px>'
		if $LIVE;
	if($LIVE) {
		if($advance) {
			$o .= "<INPUT type=hidden name=advance value=$advance>";
		}
		$o .= '<INPUT type=hidden name=showmm>';
		add_mark_form(\$o, 'main') if $m_mark_menu_show;
		add_goto_form(\$o, 'main', $page, $hra, $advance, $found)
			if $nodes > $MAIN_PI and $m_go_show;
	}

	$o .= ${ main_table('main', $what, $final, $page, $advance, $found) };

	if($LIVE) {
		$o .= '</FORM><p>';
		add_checks_script_functions(\$o);
	}

#	$o .= "<script>window.open('graph/GraphMaker','graph','resizable=yes,scrollbars=yes')</script>\n";
	$o .= '</BODY>';
	return \$o;
}

sub mark2html {
	my $what = shift;
	my $page = shift;
	my $advance = shift;
	my $found = shift;

	my $o = "$STD<TITLE>HistCite - $$title</TITLE>";

	add_body_style_main(\$o);
	add_live_menu(\$o, 'mark');
	my $sh = ''; $sh = "($MARKS)" if $MARKS;
	$o .= head_section("<b>Marked Record List</b> $sh", 'mark');
	$o .= new_table_menu('mark') if $m_ai_show;

	return \"$o$empty_list" unless $MARKS;

	$o .= "<FORM method=post name=t style=margin:2px>\n";
	if($advance) {
		$o .= "<INPUT type=hidden name=advance value=$advance>";
	}
	$o .= '<INPUT type=hidden name=showmm>';
	add_mark_form(\$o, 'main') if $m_mark_menu_show;
	add_goto_form(\$o, 'mark', $page, $hra, $advance, $found)
		if $MARKS > $MAIN_PI and $m_go_show;

	$o .= ${ main_table('mark', $what, '', $page, $advance, $found) };

	$o .= '</FORM>';
	add_checks_script_functions(\$o);
	$o .= '</BODY>';

	return \$o;
}

sub temp2html {
	my $what = shift;
	my $page = shift;
	my $advance = shift;
	my $found = shift;

	my $o = "$STD<TITLE>HistCite - $$title</TITLE>";

	add_body_style_main(\$o);
	add_live_menu(\$o, 'temp');

	my @t = keys %{$hrt};
	my $recs = @t;
	my $head = ($recs or $temp_head) ? "List of <b>$recs</b> Records" : 'New Search';
	$o .= head_section($head, 'temp', $temp_head, $recs, $what);
	$o .= new_table_menu('temp') if $m_ai_show;

	return \$o unless @tl;

	$o .= "<FORM method=post name=t style=margin:2px>\n";
	if($advance) {
		$o .= "<INPUT type=hidden name=advance value=$advance>";
	}
	$o .= '<INPUT type=hidden name=showmm>';
	$o .= '<INPUT type=hidden name=showsf>';
	add_mark_form(\$o, 'main') if $m_mark_menu_show;
	add_search_form(\$o) if $m_search_form_show;
	if($recs > $MAIN_PI) {
		add_goto_form(\$o, 'temp', $page, $hra, $advance, $found) if $m_go_show;
	}

	$o .= ${ main_table('temp', $what, '', $page, $advance, $found) } if $recs;

	$o .= '</FORM>';
	add_checks_script_functions(\$o);
	$o .= '</BODY>';

	return \$o;
}

sub main_table {
	my $ent = shift;
	my $what = shift;
	my $final = shift;
	my $page_item = shift;
	my $advance = shift;
	my $found = shift;

	my $hr = $hr{$ent};
	my $v = $view{main}{$VIEW};

	my $table_interval = $MAIN_TI;
	$table_interval *= 3 if 'cust' eq $VIEW && 'brief' eq $REC_SHOW;
	my $page_interval = $MAIN_PI;
	my %colorif; $colorif{$what} = $SORT_COLOR;
	my %color = map { ($_,'') } keys %{ $v };
	$color{$what} = ' class=sc';
	local $|=1;
	my($term,$hifi) = ('','');
	if('temp' eq $ent) {
		($term,$hifi) = ($temp_term, $temp_what);
	}

	my $index_name = "index-$what";
	if($what ne $PAGER{$ent} or !@{ $pager{$ent} }) {
		if($hra == $hr and 'tl' eq $what) {
			@{ $pager{$ent} } = @tl;
		} else {
			@{ $pager{$ent} } = $sorted_by{$what}->($hr);
		}
		$PAGER{$ent} = $what;
	} elsif($change_sort_order) {
		@{ $pager{$ent} } = reverse @{ $pager{$ent} };
	}
	my($i_start, $i_end);
	$i_start = $page_item;
	$i_end = $i_start + $page_interval - 1;
	$i_end = $i_start + 3 if $CUST;
	$i_end = $#{$pager{$ent}} if $i_end > $#{$pager{$ent}};

	my $o = ''; my $pi = '';
	$pi = page_index($hra, $pager{$ent}, $what, $index_name, $page_interval, $page_item) unless $CUST;
	$o .= "$pi\n" if $pi;

	nav_bar(\$o, $i_start, $MAIN_PI, $#{$pager{$ent}}, '') if $LIVE && !$CUST;
	$o .= qq(<TABLE border=0 width="100%" cellpadding=5 cellspacing=2 style="border: 2px solid $TABLE_BORDER_COLOR;margin: 4px 0;">\n);
	my($header,$colspan) = $CUST ? main_header_cust($what) : main_header($what);
	#both ie mess up align when colspan=0
	my $last_py = 0;

	for(my $i = $i_start, $j=0; $i <= $i_end; ++$i, ++$j) {
		my $pub = $hra->{$pager{$ent}->[$i]};
		unless($pub) {	#changed nodes may disappear from a temp list
			--$j; next;		#may want a better way later
		}
		my $n = $pub->{tl};

		$o .= $header if 0 == $j % $table_interval;
		if('tl' eq $what and $pub->{py} ne $last_py) {
			$last_py = $pub->{py};
			$o .= "<TR><TD colspan=$colspan align=center class=yr>$last_py\n";
		}

		if(!$found and $i==$i_start) {
		}
		$o .= '<TR valign=top align=right';
		$o .= ' class='. ($j % 2 ? 'evn' : 'odd');
		$o .= '><TD>'. (1 + $i);

		# Nodes / Authors
		$o .= '<TD align=left>';
		if($LIVE and ($MARKS or $m_mark_menu_show)) {
			my $chk = ($hrm->{$pub->{rid}} ? 'checked' : '');
			$o .= "<INPUT name=node type=checkbox value=$n $chk";
			$o .= ' disabled' unless $m_mark_menu_show;
			$o .= '> ';
		}
		$o .= ${ citation2html($n, undef, $what, $term, $hifi, 'main') };

		# LCS
		if($v->{lcs} or $CUST) {
			$o .= "<TD$color{lcs}>";
			if($LIVE and $pub->{lcs} > 0) {
				##like this or done in lister_link(); see LCR
				my $link = $TL_MODIFIED ? '#' : "/citers/$n/";
				$o .= "<a href=$link class=nu>$pub->{lcs}</a>";
			} elsif(!$HTML_LIMITS or ($pub->{lcs} == 1 or $pub->{lcs} > $HTMLPUBS)) {
				$o .= list_data($pub->{lcs}, $colorif{lcs}, $pub->{cited}[0], $n,
					undef, $color{lcs}, 'citers', undef, undef, 'cited');
			} else {
				$o .= "$pub->{lcs}";
			}
		}

		# LCS/t
		$o .= "<TD$color{lcst}>". nbsp($pub->{lcst}, $dec{lcst})
			if($v->{lcst} or $CUST);

		# LCSx
		$o .= "<TD$color{lcsx}>$pub->{lcsx}"
			if $v->{lcsx} or $CUST;

		# GCS
		$o .= "<TD$color{tc}>" .(-1==$pub->{tc}?'&nbsp;':$pub->{tc})
			if $v->{tc} or $CUST;

		# GCS/t
		$o .= "<TD$color{gcst}>". nbsp($pub->{gcst}>-1? $pub->{gcst}:'', $dec{gcst})
			if($v->{gcst} or $CUST);

		# OCS
		$o .= "<TD$color{scs}>" .(-1==$pub->{scs}?'&nbsp;':$pub->{scs})
			if $v->{scs} or $CUST;

		# NA
		$o .= "<TD$color{na}>$pub->{na}" if $v->{na} or $CUST;

		# LCR
		if($v->{lcr} or $CUST) {
			$o .= "<TD$color{lcr}>";
			if($LIVE && $pub->{lcr}) {
				my $link = $TL_MODIFIED ? '#' : "/citees/$n/";
				$o .= "<a href=$link class=nu>$pub->{lcr}</a>";
			} elsif(!$HTML_LIMITS or ($pub->{lcr}==1 or $pub->{lcr} > $HTMLPUBS)) {
				$o .= list_data($pub->{lcr}, $colorif{lcr}, $pub->{cites}[0], $n,
					undef, ($LIVE?undef:$color{lcr}), 'citees', undef, undef, 'cites');
					#need to clean this mess
			} else {
				$o .= $pub->{lcr};
			}
		}

		# CR
		$o .= "<TD$color{ncr}>$pub->{ncr}" if $v->{ncr} or $CUST;

		# LCSb
		if($v->{lcsb} or $CUST) {
			$o .= "<TD$color{lcst}>". ($pub->{lcsb}>-1? $pub->{lcsb} :'&nbsp;');
		}

		# LCSe
		if($v->{lcse} or $CUST) {
			$o .= "<TD$color{lcst}>". ($pub->{lcse}>-1? $pub->{lcse} :'&nbsp;');
		}

		# LCS(e/b)
		if($v->{eb} or $CUST) {
			$o .= "<TD$color{lcst}>";
			$o .= show_lcseb($pub);
		}
		$o .= "\n";
	}
	$o .= "</TABLE>\n";
	$o .= '<style>b.ind {font-size: .8em;}</style>';
	nav_bar(\$o, $i_start, $MAIN_PI, $#{$pager{$ent}}, '#bot') if $LIVE && !$CUST;
	$o .= $pi;
	$o .= '<p><br>' if $m_go_show && $LIVE;
	if('base' ne $VIEW && $stats_quarts{$what}) {
		my($q1, $me, $q3, $n, $N) = get_median($ent, $what);
		if('n/a' ne $q1) {
			$q1 = sprintf('%.2f', $q1);
			$me = sprintf('%.2f', $me);
			$q3 = sprintf('%.2f', $q3);
		}
		$o .= "<SCRIPT>document.getElementById('q1').innerHTML='$q1';";
		$o .= "document.getElementById('erecs').innerHTML=' ($n recs)';" if $n && $N > $n;
		$o .= "document.getElementById('median').innerHTML='$me';";
		$o .= "document.getElementById('q3').innerHTML='$q3';</SCRIPT>";
	}
	return \$o;
}

sub main_header {
	my $what = shift;
	my $cols = 0;

	my %rev = map { ($_, '') } keys %{$view{main}{$VIEW}};
	$rev{$what} = '?rev=1' if $LIVE;
	my $o = "<TR bgcolor=$TH_COLOR>";

	$o .= "<TD align=right>#";
	$o .= '<TH>';
	for my $f qw(tl au1 so) {
		$o .= " / " if 'tl' ne $f;
		$o .= glink("index-$f.html$rev{$f}",$f{$f},($f eq $what ? $SORT_COLOR :''));
	}
	$cols = 2;
	for my $f qw(lcs lcst lcsx tc gcst scs na lcr ncr lcsb lcse eb) {
		if($view{main}{$VIEW}{$f}) {
			$o .= "<TH>". glink("index-$f.html$rev{$f}",$f{$f},($f eq $what ? $SORT_COLOR : ''));
			++$cols;
		}
	}
	$o .= "\n";
	return ($o, $cols);
}

sub main_header_cust {
	my $what = shift;
	my $cols = 0;

	my $o = "<TR bgcolor=$TH_COLOR>";

	$o .= "<TD align=right>#";
	$o .= '<TH>';
	for my $f qw(tl au1 so) {
		$o .= " / " if 'tl' ne $f;
		$o .= qq(<a href=#>$f{$f}</a>);
	}
	$cols = 2;
	for my $f qw(lcs lcst lcsx tc gcst scs na lcr ncr lcsb lcse eb) {
		$o .= "<TH><INPUT type=checkbox name=main value=$f";
		$o .= $view{main}{cust}{$f} ? " CHECKED" : '';
		$o .= qq(><br><a href=#>$f{$f}</a>);
		++$cols;
	}
	$o .= "\n";
	return ($o, $cols);
}

sub ausos_header {
	my $what = shift;
	my $ent = shift;
	my %rev = map { ($_, '') } keys %{$view{$ent}{$VIEW}};
	$rev{$what} = '?rev=1' if $LIVE;
	$f{name} = ('wd' eq $ent ? 'Word'
		: defined $f_ful{$ent} ? $f_ful{$ent} : 'Name');
	my %colorif; $colorif{$what} = $SORT_COLOR;
	my $o = "<TR bgcolor=$TH_COLOR><TD align=right>#";
	for my $f (@{ $cols{$ent} }) {
		next unless $view{$ent}{$VIEW}{$f};
		my $head = $f{$f};
		$head = "T$head" if $f =~ /^[lg]/;
		if('perc' eq $f) {
			$o .= "<TD>";
			$o .= $head;
		} else {
			$o .= "<TH>";
			$o .= glink("$ent-$f.html$rev{$f}",$head,$colorif{$f});
		}
	}
	return "$o\n";
}

sub page_index {
	my $hr = shift;
	my $ar = shift;
	my $what = shift;
	my $name = shift;
	my $page_interval = shift;
	my $item = shift||0;
	my $field = ('au1' eq $what ? 'au' : $what);
	use integer;
	my $pages = ($#$ar + 1) / $page_interval;
	++$pages if ($#$ar + 1) % $page_interval;
	my $page = ($item + 1) / $page_interval;
	++$page if ($item + 1) % $page_interval;
	my $o = '';
	return $o if $LIVE and !$DO_PAGE_INDX;
	return $o if 1 >= $pages and not 1 < $page;
	$o = '<div style="margin: 5px 0;font:12px Verdana;">';
	$o .= "Page&nbsp;<b>$page</b> of $pages";
	my $page_start = $page * $page_interval - $page_interval;
	my $p = 1;
	if($page > 100) {
		$p = page_step(\$o, $hr, $ar, $name, $p, 100, $page, $field, $page_interval);
		$o .= ' | ';
	}
	$p = page_step(\$o, $hr, $ar, $name, $p, 10, $page, $field, $page_interval) if $page > 10;
	$o .= '<span class=nonprn>: [ ';
	my $next = $p + 10;
	for(; $p < $next and $p <= $pages; ++$p) {
		my $page_num = $name;
		$page_num .= "-$p" if $p > 1;
		$page_num .= '.html';
		$o .= ' &nbsp;';
		$o .= "<a href=$page_num class=nu>" if $p != $page
			|| ($p == $page && $item != $page_start)
			and ($LIVE
			or (('tl' eq $what or 'name' eq $what) && (!$HTML_TL2 or $p <= $HTMLPAGE))
			or $p <= $HTMLPAGE);
		$o .= $p;
		if($DO_PAGE_EXT) {
			my $pindex = $ar->[($p-1)*$page_interval];
			$o .= page_ext($hr, $pindex, $field);
		}
		$o .= '</a>' if $p != $page
			|| ($p == $page && $item != $page_start)
			and ($LIVE
			or (('tl' eq $what or 'name' eq $what) && (!$HTML_TL2 or $p <= $HTMLPAGE))
			or $p <= $HTMLPAGE);
		$o .= '&nbsp;' if $DO_PAGE_EXT;
	}
	$o .= ' ]</span>';
	my $tens = 100 * (($p-2) / 100);
	if($p <= $pages and  $p % 100 and  ($p - $tens+100)>10) {
		my $next = (101+$tens > $pages ? 10+$pages : 101+$tens);
		$p = page_step(\$o, $hr, $ar, $name, $p, 10, $next, $field, $page_interval);
		$o .= ' | ' if $p < $pages;
	}
	$p = page_step(\$o, $hr, $ar, $name, $p, 100, 100+$pages, $field, $page_interval) if $p <= $pages;
	$o .= "</div>\n";
	return $o;
}

sub page_step {
	my($sr, $hr, $ar, $name, $start, $step, $page, $field, $page_interval) = @_;
	my $p = $start;
	--$page;
	use integer;
	$page = $step * ($page / $step) ;
	for(; $p < $page ; $p += $step) {
		my $page_num = $name;
		$page_num .= "-$p" if $p > 1;
		$page_num .= '.html';
		$$sr .= ' &nbsp;';
		$$sr .= "<a href=$page_num class=nu>"
			if ($LIVE
			or (('tl' eq $field or 'name' eq $field) && (!$HTML_TL2 or $p <= $HTMLPAGE))
			or $p <= $HTMLPAGE);
		$$sr .= $p;
		if($DO_PAGE_EXT) {
			my $pindex = $ar->[($p-1)*$page_interval];
			$$sr .= page_ext($hr, $pindex, $field);
		}
		$$sr .= '</a>'
			if ($LIVE
			or (('tl' eq $field or 'name' eq $field) && (!$HTML_TL2 or $p <= $HTMLPAGE))
			or $p <= $HTMLPAGE);
		$$sr .= '&nbsp;';
		$$sr .= '&nbsp;' if $DO_PAGE_EXT;
	}
	return $p;
}

sub page_ext {
		my($hr, $pindex, $field) = @_;
		my $ext;
		if('au' eq $field) {
			my @au = split /; /, $hr->{$pindex}->{$field};
			$ext = $au[0];
		} elsif('tl' eq $field) {
			$ext = $hr->{$pindex}->{py} . show_date($hr->{$pindex});
		} else {
			$ext = $hr->{$pindex}->{$field};
			$ext = 'na' if not defined $ext;
		}
		$ext = nbsp($ext, $dec{$field}) if $dec{$field};
		return "&nbsp;($ext)";
}

sub ausos2html {
	my $ent = shift;
	my $what = shift;
	my $final = shift;
	my $item = shift;
	my $advance = shift;
	my $found = shift;

	my %colorif; $colorif{$what} = $SORT_COLOR;
	my %color = map { ($_,'') } keys %{ $view{$ent}{$VIEW}};
	$color{$what} = ' class=sc';
	my($hr,$ar,$head,$titl,$tag);
	$hr = $hr{$ent}; $ar = $ari{$ent};
	$th{name} = ('wd' eq $ent ? 'word'
		: defined $f_ful{$ent} ? lc $f_ful{$ent} : 'name');
	if('au' eq $ent) {
		$head = 'All-Author'; $tag = 'aal';
	} elsif('so' eq $ent) {
		$head = 'Journal'; $tag = 'jl';
	} elsif('wd' eq $ent) {
		$head = 'Word(<a href=# title=" '. inf_wd() .' " class=helpa>i</a>)'; $tag = 'wd';
	} elsif('tg' eq $ent) {
		$head = 'Tag'; $tag = '';
	} else {
		$head = defined $f_ful{$ent} ? $f_ful{$ent} : 'Unknown';
		$head = "Document $head" if 'la' eq $ent;
	}
	$head .= ' List';

	my $o = "$STD<HEAD><TITLE>HistCite - $$title</TITLE></HEAD>\n";
	add_body_style_main(\$o);
	add_live_menu(\$o, $ent) if $LIVE;

	my $items = @{$ar};

	my $subhead = '';
	if('wd' eq $ent and $items) {
		$subhead .= "($items) ";
		$subhead .= "Word&nbsp;count:&nbsp;$wdN, All&nbsp;words&nbsp;count:&nbsp;"
			. ($wdN + $wdN2);
	} elsif('py' eq $ent and $items) {
		$subhead .= "($items: $net_first_year - $net_last_year)\n";
		$subhead .= "&nbsp; <a href=# OnClick=\"window.open('../graph/histo_py.html','hipy',$win_opts)\" class=nonprn>Histogram</a>";
	} elsif($items) {
		$subhead .= "($items)";
	}

	$o .= head_section("<b>$head</b>", $ent, $subhead, $items);
	$o .= new_table_menu($ent) if $m_ai_show or !$LIVE;

	unless($NODES) {
		$o .= '<div align=center style="margin:20px 0;"><i>This collection is empty. Go to <span style="font-style:normal;">File -&gt; Add File...</span> to add records to this collection.</i></div>';
		$o .= '<div style="position:absolute;left:20%;font-size:18pt"><h1>HistCite&trade;</h1>Bibliometric Analysis and Visualization Software</div>';
		return \"$o</BODY>"
	}
	return \"$o$empty_list" unless $items;

	if($LIVE) {
		$o .= '<FORM method=POST name=t style=margin:2px>';
	}
	my %edit = qw(au 1 in 1 i2 1);
	if($LIVE) {
		if($advance) {
			$o .= "<INPUT type=hidden name=advance value=$advance>";
			$o .= "<INPUT type=hidden name=item value=$item>" if 'next' eq $advance;
		}
		$o .= '<INPUT type=hidden name=showmm>';
		$o .= '<INPUT type=hidden name=showem>';
		add_mark_form(\$o, $ent) if $m_mark_menu_show;
		add_edit_form(\$o, $ent) if $m_edit_menu_show and $edit{$ent};
		add_goto_form(\$o, $ent, $item, $hr, $advance, $found)
			if $items > $AU_PI and $m_go_show;
	}

	if($what ne $PAGER{$ent} or !@{ $pager{$ent} }) {
		@{ $pager{$ent} } = $ausos_by->($what, $hr);
		$PAGER{$ent} = $what;
	} elsif($change_sort_order) {
		@{ $pager{$ent} } = reverse @{ $pager{$ent} };
	}
	my($i_start, $i_end);
	$i_start = $item;
	$i_end = $i_start + $AU_PI - 1;
	$i_end = $#{ $pager{$ent} } if $i_end > $#{ $pager{$ent} };

	my $pi = '';
	$pi = page_index($hr, $pager{$ent}, $what, "$ent-$what", $AU_PI, $i_start);
	$o .= $pi;

	nav_bar(\$o, $i_start, $AU_PI, $#$ar, '') if $LIVE;
	$o .= qq(<TABLE border=0 cellpadding=5 cellspacing=2 style="border: 2px solid $TABLE_BORDER_COLOR;margin: 4px 0;">\n);
	my $header = ausos_header($what, $ent);

	my @cols = ();
	for my $f (@{$cols{$ent}}) {
		next unless $view{$ent}{$VIEW}{$f};
		push @cols, $f;
	}
	for($i = $i_start, $j=0; $i <= $i_end; ++$i, ++$j) {
		$o .= $header if 0 == $j % $AU_TI;

		my $k = $pager{$ent}->[$i];
		my $item = $hr->{$k};
		my ($node1) = split ',', $hr->{$k}->{nodes}, 2;
		my $pubs = $hr->{$k}->{pubs};
		$o .= '<TR valign=top align=right';
		$o .= ' class='. ($j % 2 ? 'evn' : 'odd');
		$o .= '><TD>'. (1 + $i);
		for my $f (@cols) {
			$o .= "<TD";
			$o .= " align=left" if 'name' eq $f;
			$o .= $color{$f};# unless 'pubs' eq $f;
			$o .= '>';
			if($LIVE and $m_form_on and 'name' eq $f) {
				my $click = '';
				$click = 'onClick="check_newedit()"' if $m_edit_menu_show and $edit{$ent};
				$o .= "<INPUT name=node type=checkbox value=$hr->{$k}->{n} $click>"
					if $m_mark_menu_show or $edit{$ent};
				if($m_edit_menu_show and $edit{$ent}) {
					my $i = sprintf("%i", 1+$i);
					$o .= qq(<INPUT name=nval type=hidden value="$i. $hr->{$k}->{$f}">);
				}
			}
			my $perc = 0;
			if('pubs' eq $f) {
				if($LIVE) {
					$perc = sprintf("%.$dec{perc}f", $pubs/$NODES*100);
					my $link = $TL_MODIFIED ? '#' : "/$ent/$hr->{$k}->{n}/";
					$o .= "<a href=$link class=nu title=' $perc%'>$pubs</a>";
				} elsif(!$HTML_LIMITS or ($pubs == 1 or $pubs > $HTMLPUBS)) {
					$o .= list_data($pubs, $colorif{$f}, $node1, $hr->{$k}->{n},
						$hr->{$k}->{name}, $final, $ent, $k, $hr);
				} else {
					$o .= $pubs;
				}
			} elsif('name' eq $f) {
				my $name = $hr->{$k}->{$f};
				if('wd' eq $ent) {
					$name = lc $name if !$DO_WD_UPPER;
					if($DO_WD_KEY_SHOW) {
						$name = "<i>$name</i>" if 0b10 == ($item->{orig} & 0b10);
						$name = "<b>$name</b>" if 0b11 == $item->{orig};
					}
				} elsif('tg' eq $ent) {
					$name = $name ? "$k: $name" : $k;
				}
				$o .= $name;
##				$o .= (('wd' eq $ent and not $DO_WD_UPPER) 
##					? lc $name : ('tg' eq $ent
##					? ($name ? "$k: $name" : $k) : $name) );
			} elsif('perc' eq $f) {
				$o .= $perc ? $perc : sprintf("%.$dec{perc}f", $pubs/$NODES*100);
			} else {
				my $v = $hr->{$k}->{$f};
				$v = $v > -1 ? $v : '';
				my $perc = 0;
				if($v) {
					if('lcs' eq $f) {
						$perc = sprintf("%.$dec{perc}f%%", $v/$net_tlcs*100);
					} elsif('gcs' eq $f) {
						$perc = sprintf("%.$dec{perc}f%%", $v/$net_tgcs*100);
					}
				}
				$o .= "<a title=' $perc' class=ank>" if $perc;
				$o .= '' eq $v ? '&nbsp;' : $dec{$f} ? sprintf("%.$dec{$f}f", $v) : $v;
				$o .= "</a>" if $perc;
			}
		}
		$o .= "\n";
	}
	$o .= "</TABLE>\n";
	nav_bar(\$o, $i_start, $AU_PI, $#$ar, '#bot') if $LIVE;
	$o .= $pi;
	if($LIVE) {
		$o .= '</FORM>';
		add_checks_script_functions(\$o);
		$o .= '<p><br>' if $m_go_show;
	}
	return \"$o</BODY>";
}

sub outs2html {
	my($what, $final, $item, $advance, $found) = @_;
	my %colorif; $colorif{$what} = $SORT_COLOR;
	my %color = map { ($_,'') } keys %{ $view{or}{$VIEW}};
	$color{$what} = ' class=sc';

	my $o = "$STD<HEAD><TITLE>HistCite - $$title</TITLE></HEAD>\n";
	$o .= "<!-- http://wos9.isiknowledge.com/ -->\n";
	add_body_style_main(\$o);
	add_live_menu(\$o, 'or') if $LIVE;
	$o .= <<"" if $LIVE;
<STYLE>
div.tipdown { cursor: default; }
div.tipdown div { display: none; }
div.tipdown:hover { position: relative; z-index: 2; }
div.tipdown:hover div {
	position: absolute; top: 1.2em; right:0; display: block; white-space: nowrap; background: #fff;
	border: solid #000 1px; border-top: 0; padding: 2px 6px;
}
td div.CR {
	padding-left: 2em;
	text-indent: -2em;
}
</STYLE>

	my $items = @ori;

	my $s = '';
	if($LIVE and $items) {
		$s = '<span class=nonprn>(';
		add_js_switch(\$s, 'icr', 'records');
		$s .= ')</span>';
	} elsif(!$LIVE) {
		$s = "(top $AU_PI shown)";
	}
	my $subhead = '';
	$subhead = "($items) " if $items;
	$subhead .= "including $NLR records" if $NLR;
	$subhead .= ", <span id=nodecnt2>...</span> on this page" if $LIVE and $items;
	$subhead .= " $s";
	$o .= head_section('<b>Cited Reference List</b>', 'or', $subhead);
	$o .= new_table_menu('or') if $m_ai_show or !$LIVE;

	unless($NODES) {
		$o .= '<div align=center style="margin:20px 0;"><i>This collection is empty. Go to <span style="font-style:normal;">File -&gt; Add File...</span> to add records to this collection.</i></div>';
		$o .= '<div style="position:absolute;left:20%;font-size:18pt"><h1>HistCite&trade;</h1>Bibliometric Analysis and Visualization Software</div>';
		return \"$o</BODY>"
	}
	return \$o unless $items;

	my (%pat, %patrep);
	$pat{'ISI-DIALOG'} = '^(\w+-\w+)?-(\d{4})-([-\w]+)';
	$patrep{'ISI-DIALOG'} = '-(V|P)\d+.*';
	$pat{'ISI-WOS'} = '^([^,]+), +(\d{4}), +([^,]+)';
	$patrep{'ISI-WOS'} = '';

	my @ori2 = ();
	my $ent = 'or';
	my $hr = \%or;
	my $aro;
	if($LIVE) {
		pager_sort($ent,$what);
		$aro = $pager{or};
	} else {
		pager_sort($ent,'pubs');
		$aro = $pager{or};
		unless('pubs' eq $what) {
			my $i = 0;
			for my $ci (@{ $aro }) {
				push @ori2, $ci;
				++$i; last if $AU_PI == $i;
			}
			@ori2 = sort { $or{$a}->{$what} cmp $or{$b}->{$what} } @ori2;
			$aro = \@ori2;
		}
	}

	my($i_start, $i_end);
	$i_start = $item||0;
	$i_end = $i_start + $AU_PI - 1;
	$i_end = $#{ $pager{$ent} } if $i_end > $#{ $pager{$ent} };

	my $ar = $aro;
	add_WoS_script(\$o);
	$o .= '<FORM method=POST name=t style=margin:2px>'
		if $LIVE;

	if($LIVE) {
		if($advance) {
			$o .= "<INPUT type=hidden name=advance value=$advance>";
			$o .= "<INPUT type=hidden name=item value=$item>" if 'next' eq $advance;
		}
		$o .= '<INPUT type=hidden name=showmm>';
		$o .= '<INPUT type=hidden name=showem>';
		$o .= '<INPUT type=hidden name=showicr>';
		add_mark_form(\$o, $ent) if $m_mark_menu_show;
		add_edit_form(\$o, $ent) if $m_edit_menu_show;
		add_goto_form(\$o, $ent, $item, $hr, $advance, $found)
			if $items > $AU_PI and $m_go_show;
	}

	nav_bar(\$o, $i_start, $AU_PI, $#$ar, '') if $LIVE;

	$o .= qq(<TABLE border=0 cellpadding=5 cellspacing=2 style="border: 2px solid $TABLE_BORDER_COLOR;margin: 4px 0">\n);
	my %rev = map { ($_, '') } keys %{$view{or}{$VIEW}};
	$rev{$what} = '?rev=1' if $LIVE;
	my(@h, $header);
	$header = "<TR bgcolor=$TH_COLOR><TD align=right>#<TH colspan=2>";
	for my $s qw(ca cy so) {
		push @h, ''.($colorif{$s} ? '<SPAN class=sc>':''). "<a href=or-$s.html$rev{$s}>$sel{$s}</a>". ($colorif{$s} ? '</SPAN>':'');
	}
	do { local $" = ' / '; $header .= "@h"; };
	$header .= "<TH>". glink("or-pubs.html$rev{pubs}",'Recs',$colorif{pubs}) ."\n";
	$header .= '<TD>Percent' if $view{or}{$VIEW}{perc};

	my($i, $j) = ($i_start, 0);
	my $nc = 0;
	while($i <= $i_end) {
		my $ci = $aro->[$i];
		++$nc if exists $hrA->{$ci} and ($m_records_show or $i < $i_start + $AU_PI);
		if( (!$m_records_show and $LIVE) and exists $hrA->{$ci}) {
			++$i; ++$i_end; next;
		}

		my $citers = $or{$ci}->{pubs};
		my $n = $or{$ci}->{n};

		$o .= $header if 0 == $j % $AU_TI;
		$o .= '<TR valign=top align=right';
		$o .= ' class='. ($j % 2 ? 'evn' : 'odd');
		$o .= '><TD><a class=ank title=" row '.(1+$j).' ">'. (1 + $i).'</a>';
		$o .= '<TD align=left >'; #nowrap
		my $ref = '';
		if($LIVE and $m_form_on) {
			$ref .= "<INPUT name=node type=checkbox value=$n";
			$ref .= " onClick='check_newedit()'" if $m_edit_menu_show;
			$ref .= '> ';
			if($m_edit_menu_show) {
				my $i = sprintf("%i", 1+$i);
				$ref .= qq(<INPUT name=nval type=hidden value="$i. $or{$ci}->{cr}">);
			}
		}
		my @n = ();
		my $cr = encode_entities($or{$ci}->{cr}, '<>"&');
		my $doi;
		($cr, $doi) = split /, DOI /, $cr;
		if(exists $hrA->{$ci}) {
			@n = keys %{$hrA->{$ci}};
			$ref .= alink($hra->{$n[0]}->{tl}, $cr, 1);
			@n = map { alink($hra->{$_}->{tl}) } @n;
		} else {
			$ref .= $cr;
		}
		$ref .= ", <a href=http://dx.doi.org/$doi target=doi title=' Locate reference via DOI system'>DOI</a> $doi" if $doi;
		$o .= ' ';
		unless('pubs' eq $what) {
			my $s = $or{$ci}->{$what};
			$s =~ s!\*!\\*!g;
			$ref =~ s!($s)!<SPAN class=sc>$1</SPAN>!;
		}
		$o .= "<div class=CR>$ref</div>";
		my($au,$y,$so) = ('','','');
		if($ci =~ /^([A-Z]{2})(\d+)$/) {
			$so = $2;
		} elsif($or{$ci}->{cr} =~ /$pat{'ISI-WOS'}/) {
			$au = $1;
			$y = $2;
			$so = $3;
			$au = '' if 'ANON' eq $au;
			$au =~ s/^\*//;	# ISI better query; ^too
		} elsif($or{$ci}->{cr} =~ /^(\d{4}), +([^,]+)/) {
			$y = $1;
			$so = $2;
		}
		if(@n > 1) {
			$o .= ' &nbsp; '. (scalar @n) .': (';
			$o .= join ', ', @n;
			$o .= ')';
		}
		$o .= " | <code>$ci</code>" if $DETAIL;
		$o .= '<TD valign=center nowrap><span class=nonprn>';
		if($LIVE && !@n) {
			$o .= qq(<a href=# OnClick="window.open('../node/edit-.html?i=$n','edit','width=770,height=570,resizable=yes,scrollbars=yes');return false" title=" Make Record "><img src=/img/add.png border=0 height=13 width=13></a> &nbsp;);
		}
		if($so) {
			$o .= qq(<a href="javascript:doWoS('$au','$so','$y')" title=" Web of Science Cited Ref search ">WoS&nbsp;</a>);
		} else {
			$o .= '<span style="visibility:hidden;">WoS&nbsp;</span>';
		}
		# LCS
		$o .= "</span><TD$color{pubs}>";
		if($LIVE) {
			my $perc = sprintf("%.$dec{perc}f", $citers/$NODES*100);
			my $link = $TL_MODIFIED ? '#' : "/or/$n/";
			$o .= "<a href=$link class=nu title=' $perc%'>$citers</a>";
		} elsif(1 == $citers) {
			$o .= alink($or{$ci}->{nodes}, 1, 1);
		} elsif(!$HTML_LIMITS or $citers > $HTMLPUBS) {
			$o .= lister_upLink('', $n, $citers, $colorif{pubs});
			if ($final) {
				my $f = "$root/or/$n.html";
				if(open LI, ">$f") {
					print LI out_citers2html($ci);
					close LI;
				} else {
					print LOG "Cannot create '$f': $!\n";
				}
			}
		} else {
			$o .= $citers;
		}
		# Percent
		$o .= '<TD>'. nbsp($citers/$NODES*100, $dec{perc})
			if $view{or}{$VIEW}{perc};
		$o .= "\n";
		++$i; ++$j;
	}
	$o .= '</TABLE>';
	if($LIVE) {
		nav_bar(\$o, $i_start, $AU_PI, $#$ar, '#bot') if $LIVE;
		$o .= '</FORM>';
		add_checks_script_functions(\$o);
		$o .= "<SCRIPT>document.getElementById('nodecnt').innerHTML=$nc;</SCRIPT>";
		$o .= "<SCRIPT>document.getElementById('nodecnt2').innerHTML=$nc;</SCRIPT>";
		$o .= '<p><br>' if $m_go_show;
	}
	return \"$o</BODY>";
}

sub list_data {
	my $count = shift;
	my $color = shift;
	my $node = shift;
	my $serial = shift;	#$hr->{$k}->{n} for a list's parent
	my $name = shift;		#$hr->{$k}->{name} parent's canonical name
	my $final = shift;
	my $list_loc = shift;	#also defines $hifi for lister2html()
	my $key2 = shift;		#for parent's name (isn't always 'name'?)
	my $hr = shift;
	my $cite_rel = shift;
	my $s = '';

	if(0 == $count) {
		$s .= 0;
	} elsif (1 == $count) {
		$s .= alink($node, 1, 1);
	} else {
		if($LIVE) {
			$s .= lister_link(($cite_rel?$list_loc:''), $serial, $count, $color, $name);
		} else {
			$s .= lister_upLink(($cite_rel?$list_loc:''), $serial, $count, $color, $name);
		}
		if($final) {
			my $f = "$root/$list_loc/$serial.html";
			if(open LI, ">$f") {
				if($cite_rel and ('cites' eq $cite_rel or 'cited' eq $cite_rel)) {
					print LI ${ citers2html($tl[$serial], $cite_rel) };
				} else {
					print LI ${ lister2html($hr, $key2, $list_loc) };
				}
				close LI;
			} else {
				# need better feedback "listing for ($key2 ? $key2 : $cite_rel) in $f"
				print LOG "Cannot create '$f': $!\n";
			}
		}
	}
	return $s;
}

sub ml2html {
	my($what, $final, $item, $advance, $found) = @_;
	my %colorif; $colorif{$what} = $SORT_COLOR;
	my %color = map { ($_,'') } keys %{ $view{or}{$VIEW}};
	$color{$what} = ' class=sc';

	my $o = "$STD<HEAD><TITLE>HistCite - Missing links: $$title</TITLE></HEAD>\n";
	add_body_style_main(\$o);
	add_live_menu(\$o, 'ml');
	my $items = @mli;

	$o .= head_section('<b>Missing links List</b>', 'or', "($items)");
	$o .= new_table_menu('ml') if $m_ai_show;

	return \$o unless @mli;

	my $ent = 'ml';
	if($LIVE) {
		pager_sort($ent,$what);
	}
	my($i_start, $i_end);
	$i_start = $item||0;
	$i_end = $i_start + $MAIN_PI - 1;
	$i_end = $#{ $pager{$ent} } if $i_end > $#{ $pager{$ent} };

	add_WoS_script(\$o);

	$o .= '<FORM method=post name=t style=margin:2px>';
	if($LIVE) {
		if($advance) {
			$o .= "<INPUT type=hidden name=advance value=$advance>";
			$o .= "<INPUT type=hidden name=item value=$item>" if 'next' eq $advance;
		}
		$o .= '<INPUT type=hidden name=showmm>';
		$o .= '<INPUT type=hidden name=showem>';
		add_mark_form(\$o, $ent) if $m_mark_menu_show;
		add_edit_form(\$o, $ent) if $m_edit_menu_show;
		add_goto_form(\$o, $ent, $item, $hr, $advance, $found)
			if $items > $MAIN_PI and $m_go_show;
	}
	nav_bar(\$o, $i_start, $MAIN_PI, $#$ar, '') if $LIVE;
	$o .= qq(<TABLE border=0 cellpadding=5 cellspacing=2 style="border: 2px solid $TABLE_BORDER_COLOR;margin: 4px 0;">\n);
	my %rev = map { ($_, '') } keys %{$view{or}{$VIEW}};
	$rev{$what} = '?rev=1' if $LIVE;
	my(@h, $header);
	$header = "<TR bgcolor=$TH_COLOR><TD>#<TH><TH colspan=2>";
	for my $s qw(ca cy so cr) {
		push @h, ''.($colorif{$s} ? '<SPAN class=sc>':''). "<a href=ml-$s.html$rev{$s}>$sel{$s}</a>". ($colorif{$s} ? '</SPAN>':'');
	}
	$header .= join ' / ', @h;
	$header .= "<TH align=right>"
		. glink("ml-pubs.html$rev{pubs}",'Recs',$colorif{pubs}) ."\n";
	$header .= '<TD align=right>Percent' if 'bibl' eq $VIEW;

	my($i, $j);
	my $ar = $pager{$ent};
	for($i=$i_start, $j=0; $i<=$i_end; ++$i, ++$j) {
		$o .= $header if 0 == $j % $MAIN_TI;
		my $cr = $ar->[$i];
		my $n = $ml{$cr}->{n};
		my $bgc .= 'class='. ($j % 2 ? 'evn' : 'odd');
		$o .= "<TR align=right valign=top $bgc><TD>". (1+$i);
		$o .= "<TD align=left><INPUT name=node type=checkbox value=$n><TD align=left>";
		if($m_edit_menu_show) {
			my $i = sprintf("%i", 1+$i);
			$o .= qq(<INPUT name=nval type=hidden value="$i. $cr">);
		}
		my $ref = $hr{ml}->{$cr}->{cr};
		unless('pubs' eq $what) {
			my $s = $ml{$cr}->{$what};
			$s =~ s!\*!\\*!g;
			$ref =~ s!($s)!<FONT color=$SORT_COLOR>$1</FONT>!;
		}
		$o .= "<b>$ref</b>";
		my $ml = $ml{$cr};
		$o .= '<TD>';
		$o .= qq(<a href="javascript:doWoS('$ml->{ca}','$ml->{so}','$ml->{cy}')" class=nonprn>WoS</a>) if $ml->{so};
		# Pubs
		$o .= "<TD$color{pubs}>";
		my @citers = eval($ml{$cr}->{nodes});
		my $lcs = $ml{$cr}->{pubs};
		if($LIVE) {
			$o .= "<a href=/ml/$n/ class=nu>$lcs</a>";
		} elsif(!$HTML_LIMITS or $lcs > $HTMLPUBS) {
			$o .= lister_link('', $n, $lcs, $colorif{pubs});
		} else {
			$o .= $lcs;
		}
		# Percent
		$o .= '<TD>'. nbsp($lcs/$NODES*100, $dec{perc})
			if 'bibl' eq $VIEW;
		my $bibl = 'bibl' eq $VIEW ? 1 : 0;
		for my $m (@{$ml{$cr}->{like}}) {
			$o .= "<TR $bgc><TD><TD align=right nowrap>";
			$o .= alink($m, ' '.(1+$m), 1);
			if($m_edit_menu_show) {
				$o .= ' &nbsp; ';
			} else {
				$o .= "<INPUT name=cr$i type=radio value=$m>";
			}
			my $bcr = brief_citation($m, $bibl, 1);
			if($bibl) {
				$bcr =~ s! LCS: ! <TD colspan=2 nowrap>LCS: !;
			} else {
				$bcr .= '<TD colspan=2>';
			}
			$o .= "<TD colspan=2 nowrap>$bcr\n";
		}
	}
	$o .= "</TABLE>\n";
	nav_bar(\$o, $i_start, $MAIN_PI, $#$ar, '#bot') if $LIVE;
	$o .= '</FORM>';
	add_checks_script_functions(\$o);
	return \"$o</BODY>";
}

sub nav_bar {
	my($sr, $this, $page_size, $last, $bot) = @_;
	return if ($last - $page_size) < 0;
	my $qry = '?advance=next&item=';
	my $next;
	$$sr .= "<style>a.navbtn:hover { background: $MENU_COLOR; text-decoration: none; }</style>" unless $bot;
	$$sr .= '<div class=nonprn style="margin:4px 0;font:12px Verdana;">';
	if(0 == $this) {
		$$sr .= '&nbsp;|&lt; ';
	} else {
		$$sr .= "<a href='${qry}0' class=navbtn title=' First item '>&nbsp;|&lt; </a>";
	}
	$$sr .= '&nbsp;';
	$next = $this - $page_size;
	if(0 > $next) {
		$$sr .= ' &lt;&lt; ';
	} else {
		$$sr .= "<a href='$qry$next' class=navbtn title=' Previous $page_size items '> &lt;&lt; </a>";
	}
	$$sr .= '&nbsp;';
	$next = $this - 10;
	if(0 > $next) {
		$$sr .= ' &lt; ';
	} else {
		$$sr .= "<a href='$qry$next$bot' class=navbtn title=' Previous 10 items '> &lt; </a>";
	}
	$$sr .= '&nbsp; &nbsp;';
	$next = $this + 10;
	if($next > ($last - $page_size + 10)) {
		$$sr .= ' &gt; ';
	} else {
		$$sr .= "<a href='$qry$next$bot' class=navbtn title=' Next 10 items '> &gt; </a>";
	}
	$$sr .= '&nbsp;';
	$next = $this + $page_size;
	if($next > $last) {
		$$sr .= ' &gt;&gt; ';
	} else {
		$$sr .= "<a href='$qry$next' class=navbtn title=' Next $page_size items '> &gt;&gt; </a>";
	}
	$$sr .= '&nbsp;';
	$next = $last - $page_size + 1;
	if($next == $this) {
		$$sr .= ' &gt;|';
	} else {
		$$sr .= "<a href='$qry$next#bot' class=navbtn title=' Last item '> &gt;|&nbsp;</a>";
	}
	$$sr .= '</div>';
	$$sr .= '<name id=bot>' if $bot;
}

sub show_date {
	my $pub = shift;
	my($pd, $pdm, $pdd) = ($pub->{pd}, $pub->{pdm}, $pub->{pdd});
	my $date = '';
	if('P' eq $pub->{pt}) {
		$date = " $mon[$pdm] $pdd";
	} else {
		$date = $pd;
	}
	return ($date ? " $date" : '');
}

sub show_lcseb {
	my $pub = shift;
	my $o .= $pub->{lcse} == -1									 ? '&nbsp;'
		: ($pub->{lcse} == 0 && $pub->{lcsb} == 0) ? '0'
		: ($pub->{lcse} == 0)									? "<b class=ind>0/$pub->{lcsb}</b>"
		: ($pub->{lcsb} == 0)									? "<b class=ind>$pub->{lcse}/0</b>"
		:																				sprintf("%.2f", $pub->{eb})
		;
	return $o;
}

sub citation2html {
	my $i = shift;
	my $color = shift;
	my $what = shift||'';
	my $term = shift||'';
	my $hifi = shift||'';
	my $main = shift;

	my $pub = $hra->{$tl[$i]};

	my $o = alink($i, undef) .' ';

##	$o .= " [ $temp_what : $temp_item ]<br>";
	my $au;
	if('cust' eq $VIEW && 'brief' eq $REC_SHOW) {
		$au = $pub->{au1};
		$au = ilink('au', $au);
		$au = "<SPAN class=sc>$au</SPAN>" if 'au1' eq $what;
	} else {
		$au = limit_list($pub, 'au', $CI_authors, $DO_CI_au_cut);
		my @au = split '; ', $au;
		$au[0] = ilink('au', $au[0]);
		$au[0] = "<SPAN class=sc>$au[0]</SPAN>" if 'au1' eq $what;
		if(@au > 1) {
			for(my $i=1; $i<=$#au; ++$i) {
				last if 'et al.' eq $au[$i];
				$au[$i] = ilink('au', $au[$i]);
			}
		}
		$au = join ', ', @au;
	}
	$au = hilite($au, $term) if 'au' eq $hifi;
	$o .= " $au";

	if('cust' eq $VIEW && 'brief' eq $REC_SHOW) {
		$o .= ', ';
	} else {
		$o .= "<div class=ci_title>";
##		my $ti = (encode_entities(fix_dash($pub->{ti})));
		my $ti = $pub->{ti};
##?		$ti =~ s/,(\S)/, $1/;
##		my @ti = split /([.,!?:;'"()\[\]{}<>\/\\+*\s])/, $ti;
		my @ti = split /($WD_PAT)/, $ti;
		for my $ws (@ti) {
##			for my $ws (split /-/, $ww) {
##				$ws =~ s/[,!?;'"()\[\]{}<>\/\\+*]//g;
				if($ws =~ /^\w/) {
					$ws = ilink('wd', $ws);
##					my $wsi = ilink('wd', $ws);
##					$ww =~ s/$ws/$wsi/ if $ws ne $wsi;
				}
##			}
		}
##		$ti = join ' ', @ti;
		$ti = join '', @ti;
		$ti = hilite($ti, $term) if 'wd' eq $hifi;
		$o .= "$ti</div>";
	}

	$o .= '<SPAN'. ('so' eq $what ? ' class=sc' : '') .'>';
	my $so = ('P' eq $pub->{pt} 
		? limit_list($pub, 'so', $CI_patents, $DO_CI_pn_cut)
		: ilink('so', $pub->{so}) );
	$o .= ('so' eq $hifi ? hilite($so, $term) : $so);
	$o .= '</SPAN>. ';

	$o .= '<SPAN'. ('tl' eq $what ? ' class=sc' : '') .'>';
	my $py = ilink('py', $pub->{py});
	$o .= 'py' eq $hifi ? hilite($py, $term) : $py;
	$o .= show_date($pub);
	$o .= '</SPAN>; ';
	$o .= " $pub->{vipp}" unless 'P' eq $pub->{pt};
	
	$o .= "<br>\n" . node_scores($pub)
		if not $main and 'bibl' eq $VIEW;
	$o .= "\n";
	if('or' eq $temp_what) {
		$o .= '<div class=fndCR><span class=fnd>'. get_crs($pub, $temp_item) . '</span></div>';
	}
	return \$o;
}

sub get_crs {
	my($pub, $crs) = @_;
	my @cr = ();
	my $i = 0;
	for my $c (@{$pub->{crs}}) {
		push @cr, $pub->{cr}[$i] if $crs eq $c;
		++$i;
	}
	return join '<br>', @cr;
}

sub ilink {
	my($ent,$item) = @_;
	my $ir = $hr{$ent}->{uc $item};
	unless($ir) {
		if($DIRTY && !($stopwd{uc $item} || $SMALL_WORD >= length($item) || $item =~ /^[-\d]+$/)) {
			return qq(<a title="Pending update lists" class="ci_il">$item</a>)
		} else {
			return $item;
		}
	}

	my($rper,$lper,$gper) = ('','','');
	if('bibl' eq $VIEW) {
		$rper = sprintf("(%.1f%%) ", $ir->{pubs}/$NODES*100);
		$lper = sprintf(" (%.1f%%)", $ir->{lcs}/$net_tlcs*100) if $ir->{lcs} > 0;
		$gper = sprintf("(%.1f%%)", $ir->{gcs}/$net_tgcs*100) if $ir->{gcs} > 0;
	}
	my $gcs = -1==$ir->{gcs} ? '' : ", TGCS $ir->{gcs} $gper";
	my $href = $LIVE ? "href=/$ent/$ir->{n}/" : '';
	return qq(<a $href title=" $ir->{pubs} ${rper}records, TLCS $ir->{lcs}$lper$gcs" class="ci_il">$item</a>);
}

sub citers2html {
	my $ci = shift;
	my $relation = shift;
	my $top_ci_color = 'blue';
	my $bot_ci_color = undef;
	if('cites' eq $relation) {
		$top_ci_color = undef;
		$bot_ci_color = 'blue';
	}
	my %say = (qw(cites cites cited), 'cited by');
	my $o = "<TITLE>HistCite: $$title</TITLE>\n";
	add_body_script(\$o);

	$o .= '<DIV style="padding: 5px">';
	$o .= ${ citation2html($hra->{$ci}->{tl}, $top_ci_color) };
	$o .= '</DIV>';
	$o .= "<center>$say{$relation}:</center>\n";
	my $enough = 0;
	my $j = 1;
	my(@n, $nr);
	if('cited' eq $relation) {
		#presorted by design
		$nr = \@{$hra->{$ci}->{$relation}};
	} else {
		@n = sort {$a <=> $b} @{$hra->{$ci}->{$relation}};
		$nr = \@n;
	}

	for my $i (@{$nr}) {
		if($j > $LISTN) { $enough = 1; last }
		$o .= '<DIV class='. ($j % 2 ? 'odd' : 'evn') .'>';
		$o .= "$j. ". ${ citation2html($i, $bot_ci_color) } .'</DIV>';
		++$j;
	}
	$o .= "<p>First $LISTN shown." if $enough;
	return \"$o</BODY>";
}

sub out_citers2html {
	my $ci = shift;
	my $hr = shift||\%or;
	my $o = "<TITLE>HistCite: $$title</TITLE>\n";
	add_body_script(\$o);
	$o .= "<FONT COLOR=blue>". (encode_entities($hr->{$ci}->{cr})) ."</FONT>\n";
	$o .= "<center>cited by:</center>\n";
	my @citers = eval($hr->{$ci}->{nodes});
	my $enough = 0;
	my $j = 0;
	for my $i (sort {$a <=> $b} @citers) {
		++$j;
		if($j > $LISTN) { $enough = 1; last }
		$o .= '<DIV class='. ($j % 2 ? 'odd' : 'evn') .'>';
		$o .= "$j. ". ${ citation2html($i) };
		$o .= '</DIV>';
	}
	$o .= "<p>First $LISTN shown." if $enough;
	return $o . "</BODY>";
}

sub lister2html {
	my $hr = shift;
	my $k = shift;
	my $hifi = shift||'';
	my $term = $hr->{$k}->{name} || "$k:";
	$term = lc $term if 'wd' eq $hifi and not $DO_WD_UPPER;
	my $o = "<TITLE>HistCite: $term</TITLE>\n";
	add_body_script(\$o);

	$o .= '<DIV style="padding: 5px">';
	$o .= "$term\n";
	$o .= '</DIV>';
	my $enough = 0;
	my $j = 0;
	for my $i (eval $hr->{$k}->{nodes}) {
		++$j;
		if($j > $LISTN) { $enough = 1; last }
		$o .= '<DIV class='. ($j % 2 ? 'odd' : 'evn') .'>';
		$o .= "$j. ". ${ citation2html($i, undef, undef, $term, $hifi) };
		$o .= '</DIV>';
	}
	$o .= "<p>First $LISTN shown." if $enough;
	return \"$o</BODY>";
}

sub do_save_csv {
	my $ent = shift;
	my $hr = $hr{$ent};
	my $root;
	$root = "$TmpPath".'c'. time .'.tmp';
	open EXP, ">$root" or do {
		print LOG "failed creating temp file '$root': <font color=red>$!</font>\n";
		return 0;
	};
	my @cols = ();
	do {
	for my $f (@{ $cols{$ent} }) {
		print " $f ";
		next unless exists $view{$ent}{$VIEW}{$f};
		push @cols, $f;
	}
	};
	print EXP join(',', map qq("$f{$_}"), @cols), "\n";

	my %textf = qw(name 1 cr 1);

	for my $k (@{$pager{$ent}}) {
		my @val = ();
		my $pubs;
		for my $f (@cols) {
			my $v = $hr->{$k}->{$f};
			$v = qq("$v")
				if $textf{$f};
			$pubs = $v
				if 'pubs' eq $f;
			$v = sprintf("%.$dec{$f}f", $pubs/$NODES*100)
				if 'perc' eq $f;
			push @val, $v;
		}
		print EXP join(',', @val), "\n";
	}
	close EXP;
	return $root;
}

sub do_save_export {
	my $hr = shift||$hra;
	my $root;
	my $ext = $hr == $hra ? 'txt' : 'tmp';
	$root = "$TmpPath".'e'. time ."$ext";
	open EXP, ">$root" or 
		return my_error(\"Failed creating temp file '$root': $!");

	print LOG "Saving bibliography temp to \"$root\"..";
	#print EXP "FN ISI Export Format\nVR 1.0\n";
	print EXP "FN Thomson Reuters Web of Knowledge\nVR 1.0\n";
	print EXP "MG HistCite $$VERSION\n";
	print EXP "MD ", scalar localtime, "\n";
	print EXP "MT ", fix_dash($$title_line), "\n" if $$title_line;
	print EXP "MC ", fix_dash($$caption), "\n" if $$caption;
	print EXP "MO ", fix_dash($MORIGINAL), "\n";
	print EXP "MN ", fix_dash($MNB), "\n" if $MNB;
	if($TAGS > 1) {
		my %t = map {($_,1)} keys %tg;
		delete $t{Other};
		if(%t) {
			my @tg = keys %t;
			my $tg = shift @tg;
			print EXP "TD $tg: $istag{$tg}\n";
			for $tg (@tg) {
				print EXP "   $tg: $istag{$tg}\n";
			}
		}
	}
	print EXP "ER\n\n";
	my $t = time();
	my $rid;
	while(($rid, undef) = each %{$hr}) {
		print EXP (pub_export($rid));
	}
	close EXP;
	do_done($t);
	return $root;
}

sub pub_export {
	my $rid = shift;
	my $pub = $hra->{$rid};
	my $s;
	my $o = "PT $pub->{pt}\n";
	my @au = split /; /, $pub->{au};
	for my $au (@au) { $au =~ s/ (\w+)$/, $1/ }
	$o .= 'AU '. (join "\n   ", @au) ."\n";
	if($pub->{af}) {
		$s = $pub->{af}; $s =~ s/; /\n   /g;
		$o .= "AF $s\n";
	}
	if($pub->{ae}) {
		$s = $pub->{ae}; $s =~ s/\n/\n   /g;
		$o .= "AE $s\n";
	}
	$o .= "TI $pub->{ti}\n";
	if('P' eq $pub->{pt}) {
		$o .= 'PN ';
	} else {
		$o .= 'SO ';
	}
	$o .= "$pub->{so}\n";
	$o .= "J9 $pub->{j9}\n" if $pub->{j9};
	$o .= "LA $pub->{la}\n" if $pub->{la};
	$o .= "DT $pub->{dt}\n" if $pub->{dt};
	$o .= "C1 $pub->{cs}\n" if $pub->{cs};
	for my $t qw(rp em nb de id ab) {
		next unless $pub->{$t};
		$o .= uc $t;
		my $s = $pub->{$t};
		$s =~ s/\n\s*/\n   /gs;
		$o .= " $s\n";
	}
	if($pub->{cp} and @{ $pub->{cp} }) {
		$o .= "CP $pub->{cp}[0]\n";
		for(my $i=1; $i<=$#{$pub->{cp}}; ++$i) {
			$o .= '   ';
			$o .= '   ' if $pub->{cp}[$i] =~ / /;
			$o .= "$pub->{cp}[$i]\n";
		}
	}
	$o .= "CR $pub->{cr}[0]\n" if $#{$pub->{cr}} > -1;
	for(my $i=1; $i<=$#{$pub->{cr}}; ++$i) {
		$o .= '   ' if 'P' eq $pub->{pt};
		$o .= '   ' if $pub->{cr}[$i] =~ / / or 'P' ne $pub->{pt};
		$o .= "$pub->{cr}[$i]\n";
	}
	$o .= "NR $pub->{ncr}\n" unless 'P' eq $pub->{pt};
	$o .= "TC $pub->{tc}\n" if -1 < $pub->{tc};
	$o .= "TS $pub->{scs}\n" if -1 < $pub->{scs};
	$o .= "BP $pub->{bp}\n" if $pub->{bp};
	$o .= "EP $pub->{ep}\n" if $pub->{ep};
	$o .= "AR $pub->{ar}\n" if $pub->{ar};
	$o .= "PY $pub->{py}\n" unless 'P' eq $pub->{pt};
	if($pub->{pd}) {
		$s = $pub->{pd}; $s =~ s/\n/\n   /g;
		$o .= "PD $s\n";
	}
	$o .= "VL $pub->{vl}\n" if $pub->{vl};
	$o .= "IS $pub->{is}\n" if $pub->{is};
	$o .= "DI $pub->{di}\n" if $pub->{di};
	$o .= "GA $pub->{ga}\n" if $pub->{ga};
	$o .= "UT $pub->{ut}\n" if $pub->{ut};
	$o .= "OR $pub->{SRC}\n" if $pub->{SRC};
	if(($TAGS > 1 and $pub->{tags})) {
		my $tags = ($TAGS > 1 and $pub->{tags}) ? $pub->{tags} : '';
		$tags =~ s/^ //;
		$o .= "TG $tags"; 
		$o .= "\n";
	}
	$o .= "ER\n\n";
	return $o;
}

sub do_save_export_csv {
	my $hr = shift||$hra;
	my $root;
	$root = "$TmpPath". time .".csv";
	open EXP, ">$root" or 
		return my_error(\"Failed creating temp file '$root': $!");

	print LOG "Saving bibliography as CSV to temp '$root'..";
	my $t = time();
	my @f = map uc $_, qw(pt au ae ti so j9 la dt c1 rp em nb de id ab cr ncr tc bp ep ar py pd vl is di ga ut tags);
	push @f, 'No.';

	for my $f qw(lcs lcst gcst na lcr lcsb lcse eb) {
		push @f, uc $f if $view{main}{$VIEW}{$f};
	}

	print EXP join(',', @f), "\n";

	my $rid;
	while(($rid, undef) = each %{$hr}) {
		print EXP ${pub_export_csv($rid)}, "\n";
	}
	close EXP;
	do_done($t);

	return $root;
}

sub pub_export_csv {
	my $rid = shift;
	my $pub = $hra->{$rid};
	my @v = ();
	push @v, $pub->{pt};

	my @au = split /; /, $pub->{au};
	for my $au (@au) { $au =~ s/ (\w+)$/, $1/ }
	push @v, '"'. join('; ', @au) .'"';

	my $s = $pub->{ae}||''; $s =~ s/\n/; /gs;
	push @v, qq("$s");

	$s = $pub->{ti}; $s =~ s/\n/ /gs; $s =~ s/\s\s+/ /g;
	push @v, qq("$s");

	for my $f qw(so j9 la dt) {
		my $v = $pub->{$f}||'';
		$v = qq("$v");
		push @v, $v;
	}

	$s = $pub->{cs}||''; $s =~ s/.\n/; /gs; $s =~ s/\s\s+/ /g; $s =~ s/\.$//;
	push @v, qq("$s");

	for my $f qw(rp em nb de id ab) {
		my $v = $pub->{$f}||'';
		$v =~ s/\n/ /gs;
		$v =~ s/\s\s+/ /g;
		$v =~ s/"/""/g;
		$v = qq("$v");
		push @v, $v;
	}

	#Patents not really supported now

	push @v, '"'. join('; ', @{$pub->{cr}}) .'"';

	push @v, $pub->{ncr};
	push @v, (-1 < $pub->{tc} ? $pub->{tc} : '');
	
	for my $f qw(bp ep ar py pd vl is di ga ut tags) {
		my $v = $pub->{$f}||'';
		$v = qq("$v");
		push @v, $v;
	}

	push @v, (1 + $pub->{tl});

	for my $f qw(lcs lcst lcsx gcst na lcr lcsb lcse eb) {
		push @v, $pub->{$f} if $view{main}{$VIEW}{$f};
	}

	$o = join ',', @v;
	return \$o;
}

sub GraphMaker_frames {
	my $o = <<"";
<TITLE>HistCite - Graph Maker</TITLE>
<SCRIPT>function opeNod (a) { opener.top.opeNod(a); } </SCRIPT>
<SCRIPT>function opeLod (d, a) { opener.top.opeLod(d, a); } </SCRIPT>
<FRAMESET COLS="120,*" frameborder=0>
	<FRAME src="gm" name=menu scrolling=no noresize>
	<FRAME src="pane" name="thegraph">
</FRAMESET>

	return $o;
}

sub gm {
	my $o = <<"";
<HEAD>$STD
<STYLE type="text/css">
body {
	margin: 3px;
	font-family: Verdana;
	font-size: 12px;
	white-space: nowrap;
}
input, select, textarea {
	font-size: 10px;
}
td {
	margin: 0;
	font-size: 12px;
	white-space: nowrap;
}
form {
	margin: 0;
}
input {
	margin: 0;
}
input.submit {
	margin-top: 8px;
	margin-bottom: 6px;
	font-size: 10px;
}
select {
	margin: 0;
}
hr {
	line-height: 2px;
	font-size: 2px;
}
P {
	margin: 0;
	text-indent: 1em;
	font-weight: bold;
}
.p {
	font-weight: bold;
}
div.submit {
	text-align: center;
}
div.hr {
	margin-top: 3px;
	margin-bottom: 2px;
	background: #555;
	line-height: 1px;
}
a.tog {
	font-family: monospace;
	font-size: 14px;
	font-weight: bold;
	text-decoration: none;
/*	color: black; */
}
a.tog:link {
	color: black;
}
</STYLE>
</HEAD>
<BODY VLINK=blue onLoad="focus();check_form();" bgcolor=$MENU_COLOR>
<SCRIPT>document.onkeydown = function (e) { e = e ? e : event ? event : null;
	if(e) if(e.keyCode==27) top.close();
}
function gethelpgm () {
	if('about:blank' == top.thegraph.location)
		helpurl = 'graphmaker.html';
	else
		helpurl = 'graphmakermenu.html';
	gethelp('/?help=' + helpurl);
}
$$helpjs
</SCRIPT>

	add_toggle_script(\$o);

	my $time = time;
	$o .= <<"END_GM";
<TABLE width=100%><TR><TD>
<a href="javascript:top.window.location='/graph/list.html'" style=text-decoration:none;>Graphs</a>
<TD align=right><a href=# OnClick="gethelpgm()">Help</a>
</TABLE>
<FORM target="thegraph" action=/graph/GraphMaker onSubmit="fsubmit()">
<div class=submit><INPUT class=submit type=submit value="Make graph" name=action></div>

<P>Select by</P><SELECT name=use_lcs>
<OPTION value=1 ${\($g_use_lcs ? 'selected' : '')}>LCS
<OPTION value=0 ${\($g_use_lcs ? '' : 'selected')}>GCS
</SELECT><SELECT name=use_val>
<OPTION value=1 ${\($g_use_val ? 'selected' : '')}>value
<OPTION value=0 ${\($g_use_val ? '' : 'selected')}>count
</SELECT><br>
<INPUT type=checkbox name=select ${\($g_select ? 'checked' : '')}>
Limit: <INPUT type=text name=limit size=3 value=$g_limit><br>
<INPUT type=checkbox name=marks ${\($g_marks ? 'checked' : '')}> Use $MARKS
<a href="javascript:top.opener.location.replace('/mark/index.html?'+$time)">marks</a>
<div class=hr>&nbsp;</div>

<a href=javascript:toggle('setnode') class="tog">
<span id=msetnode style=display:none>+</span><span id=lsetnode>-</span></a>
<span class=p>Node</span>
<div id=setnode>
Shape:<SELECT name=node_shape onchange=shape_check()>
<OPTION value=circle ${\('circle' eq $g_node_shape ? 'selected' : '')}> circle
<OPTION value=box ${\('box' eq $g_node_shape ? 'selected' : '')}> box
<OPTION value=plaintext ${\('plaintext' eq $g_node_shape ? 'selected' : '')}> none
</SELECT>
<br>
Size:<br>
<LABEL><INPUT type=radio name=node_scaled onchange=scaled_check() value=1 ${\($g_node_scaled ? 'checked' : '')}> Scale</LABEL>
* <INPUT type=text name=g_scale_factor size=2 value=$g_scale_factor><br>
<LABEL><INPUT type=radio name=node_scaled onchange=scaled_check() value=0 ${\($g_node_scaled ? '' : 'checked')}> Fixed</LABEL>
<INPUT type=text name=fixed_size size=2 value=$g_fixed_size>in</LABEL><br>
</div>
<div class=hr>&nbsp;</div>

<a href=javascript:toggle('setdist') class="tog">
<span id=msetdist>+</span><span id=lsetdist style=display:none>-</span></a>
<span class=p>Node distance</span>
<div id=setdist style=display:none>
Y axis: <INPUT type=text name=ranksep size=3 value=$g_ranksep>in<br>
<!--
<INPUT type=checkbox name=equally ${\($g_equally ? 'checked' : '')}> equally<br>
-->
X axis: <INPUT type=text name=nodesep size=3 value=$g_nodesep>in
</div>
<div class=hr>&nbsp;</div>

<a href=javascript:toggle('setidplc') class="tog">
<span id=msetidplc style=display:none>+</span><span id=lsetidplc>-</span></a>
<span class=p>Id placement</span>
<div id=setidplc>
<SELECT name=node_label_loc onchange=proximity_check()>
<OPTION value=inside ${\('inside' eq $g_node_label_loc ? 'selected' : '')}>inside node
<OPTION value=outside ${\('outside' eq $g_node_label_loc ? 'selected' : '')}>outside node
<OPTION value=0 ${\($g_node_label_loc ? '' : 'selected')}>none
</SELECT><br>
Proximity: <INPUT type=text name=label_dist size=2 value=$g_label_dist>
</div>
<div class="hr">&nbsp;</div>

<a href=javascript:toggle('setarrow') class="tog">
<span id=msetarrow>+</span><span id=lsetarrow style=display:none>-</span></a>
<span class=p>Arrowhead</span>
<div id=setarrow style=display:none>
Direction:${\( select_box('arrowdir',[qw(backward forward)]) )}<br>
Shape:${\( select_box('arrowtype',[qw(normal empty open none)]) )}<br>
Size: <INPUT type=text name=arrowsize size=2 value=$g_arrowsize>
</div>
<div class=hr>&nbsp;</div>

<a href=javascript:toggle('setfonts') class="tog">
<span id=msetfonts>+</span><span id=lsetfonts style=display:none>-</span></a>
<span class=p>Font sizes</span>
<style> #setfonts input { text-align: right; } </style>
<div id=setfonts style=display:none>
<table border=0 cellspacing=0 cellpadding=0>
<tr><td>Nodes: <td align=right><INPUT type=text name=nodes_font size=1 value=$g_nodes_font>pt
<tr><td>Years: <td align=right><INPUT type=text name=years_font size=1 value=$g_years_font>pt
<tr><td>Month: <td align=right><INPUT type=text name=month_font size=1 value=$g_month_font>pt
</table>
</div>
<div class=hr>&nbsp;</div>

<a href=javascript:toggle('setdisp') class="tog">
<span id=msetdisp style=display:none>+</span><span id=lsetdisp>-</span></a>
<span class=p>Display</span>
<div id=setdisp>
<INPUT type=checkbox name=connected ${\($g_connected ? 'checked' : '')}> Draw links<br>
<INPUT type=checkbox name=concentrate ${\($g_concentrate ? 'checked' : '')}> Merge links<br>
<INPUT type=checkbox name=gap_years ${\($g_gap_years ? 'checked' : '')}> Gap years<br>
<INPUT type=checkbox name=yearcount ${\($g_yearcount ? 'checked' : '')}> #&nbsp;of&nbsp;records<br>
<INPUT type=checkbox name=monthly ${\($g_monthly ? 'checked' : '')}> Months<br>
<INPUT type=checkbox name=mk_info ${\($g_mk_info ? 'checked' : '')}> Info<br>
<INPUT type=checkbox name=mk_legend ${\($g_mk_legend ? 'checked' : '')}>
Legend<SELECT name=legend_full>
<OPTION value=0 ${\($g_legend_full ? '' : 'selected')}>brief</OPTION>
<OPTION value=1 ${\($g_legend_full ? 'selected' : '')}>full</OPTION>
</SELECT>
<br>Size: <SELECT name=img_size>
<OPTION value=0 ${\($g_size ? '' : 'selected')}>full</OPTION>
<OPTION value=1 ${\(1==$g_size ? 'selected' : '')}>Letter</OPTION>
<OPTION value=2 ${\(2==$g_size ? 'selected' : '')}>window</OPTION>
</SELECT>
<INPUT type=hidden name=img_width><INPUT type=hidden name=img_height>
</div>

<div class=submit><INPUT class=submit type=submit value="Make graph" name=action></div>
<INPUT class=submit type=submit value="Export to file" name=action style="width:116px;"><br>
format: <SELECT name=format>
<OPTION value=pajek1 title="Labels limited to first author, year">Pajek 1
<OPTION value=pajek2 title="Labels include journal, volume, page">Pajek 2
<OPTION value=DOT title="Graphviz DOT format">DOT
</SELECT>
</FORM>
<SCRIPT>var f;
function check_form () {
	f = document.forms[0];
	scaled_check();
	shape_check();
	proximity_check();
}
function shape_check () {
	if('plaintext'==f.node_shape.value) {
		f.node_scaled[0].disabled = true;
		f.node_scaled[1].checked = true;
		f.g_scale_factor.disabled = true;
		f.fixed_size.disabled = false;
	} else {
		f.node_scaled[0].disabled = false;
	}
}
function scaled_check () {
	if(f.node_scaled[0].checked) {
		f.g_scale_factor.disabled = false;
		f.fixed_size.disabled = true;
	} else {
		f.g_scale_factor.disabled = true;
		f.fixed_size.disabled = false;
	}
}
function proximity_check () {
	if('outside'==f.node_label_loc.value) {
		f.label_dist.disabled = false;
	} else {
		f.label_dist.disabled = true;
	}
}
function fsubmit () {
	if(2==f.img_size.value) {
		var win;
		try { img = top.thegraph.theimage.document.body.clientWidth }
		catch (e) { img = 0 }
		if(img) {
			win = top.thegraph.theimage.document.body;
		} else {
			win = top.thegraph.document.body;
		}
		f.img_width.value=win.clientWidth;
		f.img_height.value=win.clientHeight;
	}
}
</SCRIPT>
<FORM>
<INPUT name=rest class=submit type=submit value="Restore defaults" style="width:116px;">
</FORM>
</BODY>
END_GM
	return $o;
}

sub select_box {
	my($name,$ar) = @_;
	my $o = "<SELECT name=$name>";
	for my $s (@{$ar}) {
		$o .= "<OPTION value=$s ";
		$o .= eval "(\$s eq \$g_$name ? 'selected' : '')";
		$o .= ">$s";
	}
	$o .= "</SELECT>\n";
	return $o;
}

sub select_box2 {
	my($name,$hr) = @_;
	my $o = "<SELECT name=$name>";
	for my $s (sort {$a <=> $b} keys %{$hr}) {
		$o .= "<OPTION value=$s ";
		$o .= eval "(\$s eq \$$name ? 'selected' : '')";
		$o .= ">$hr->{$s}";
	}
	$o .= "</SELECT>\n";
	return $o;
}

sub full_reset {
	my $T = time();
	print_ln($FH, \"Closing the collection..");
	undef %{$hra};
	%{$hra} = ();
	%{$hrA} = ();
	%{$hrm} = (); $MARKS = 0; $PAGER{mark} = 'tl'; @{$pager{mark}} = ();
	%{$hrt} = (); $PAGER{temp} = 'tl'; @{$pager{temp}} = ();
	@tl = ();	$NODES = 0;
	%isbook = ();
	%g = ();
	%istag = ();
##	for my $k (keys %dirty) { $dirty{$k} = 1 }
	for my $m (@all_mod) { 
		next if 'so' eq $m;
		eval "undef %$m; \$hr{$m} = \\%$m; undef \@${m}i; \$ari{$m} = \\\@${m}i;"
	}
	undef %jn; $hr{so} = \%jn; undef @jni; $ari{so} = \@jni;

	$NEEDSAVE = 0; $DIRTY = 0;
	%stats = ();
	@file = (); $FILENOW = '';
	$$title = ''; $$title_line = ''; $title_file = '';
	$$caption = '';
	$MNB = '';
	$MORIGINAL = '';
	$TAGS = 0;
	$NLR = 0;
	$net_tgcs = 0; $net_tlcs = 0; $net_tncr = 0; $net_tna = 0;
	do_done($T, $FH);
}

sub g_vars_init {
	$g_node_shape = 'circle';
	$g_fixed_size = .2;
	$g_node_scaled = 1;
	$g_scale_factor = 1.0;
	$g_ranksep = .2;
	$g_equally = 1;
	$g_nodesep = .1;
	$g_node_label_loc = 'inside';
	$g_label_dist = 1.1;
	$g_nodes_font = 9;
	$g_years_font = 10;
	$g_month_font = 8;
	$g_arrowdir = 'backward';
	$g_arrowtype = 'normal';
	$g_arrowsize = 0.6;
	$g_connected = 1;
	$g_concentrate = 0;
	$g_gap_years = 0;
	$g_yearcount = 0;
	$g_monthly = 0;
	$g_mk_info = 1;
	$g_mk_legend = 1;
	$g_legend_full = 0;
	$g_size = 2;
	$g_use_lcs = 1;
	$g_use_val = 0;
	$g_limit = 30;
	$g_select = 1;
	$g_marks = 0;
}

sub g_vars_set {
	my $q = shift;
	$g_node_shape = $q->param('node_shape');
	$g_node_scaled = $q->param('node_scaled');
	$g_scale_factor = $q->param('g_scale_factor') if defined $q->param('g_scale_factor');
	$g_fixed_size = $q->param('fixed_size') if defined $q->param('fixed_size');
	$g_ranksep = $q->param('ranksep');
#	$g_equally = $q->param('equally');
	$g_nodesep = $q->param('nodesep');
	$g_node_label_loc = $q->param('node_label_loc');
	$g_label_dist = $q->param('label_dist') if defined $q->param('label_dist');
	$g_nodes_font = $q->param('nodes_font');
	$g_years_font = $q->param('years_font');
	$g_month_font = $q->param('month_font');
	$g_arrowdir = $q->param('arrowdir');
	$g_arrowtype = $q->param('arrowtype');
	$g_arrowsize = $q->param('arrowsize');
	$g_connected = $q->param('connected')||0;
	$g_concentrate = $q->param('concentrate')||0;
	$g_gap_years = $q->param('gap_years')||0;
	$g_yearcount = $q->param('yearcount')||0;
	$g_monthly = $q->param('monthly')||0;
	$g_mk_info = $q->param('mk_info')||0;
	$g_mk_legend = $q->param('mk_legend')||0;
	$g_legend_full = $q->param('legend_full');
	$g_size = $q->param('img_size');
	if(2==$g_size) {
		$g_size_width = $q->param('img_width');
		$g_size_height = $q->param('img_height');
	}
	$g_use_lcs = $q->param('use_lcs');
	$g_use_val = $q->param('use_val');
	$g_limit = $q->param('limit');
	$g_select = $q->param('select');
	$g_marks = $q->param('marks');

	$g_scale_factor = 2 if 2 < $g_scale_factor;
}

sub m_sets_init {
	$m_mark_menu_show = 0;
	$m_sets_main_nodes = 1;
	$m_sets_main_cites = 0;
	$m_sets_main_cited = 0;
	$m_sets_main_scope = 'checks_on_page';
	$m_sets_histo_range = 'all';
	$m_sets_main_field = '#';
	$m_sets_main_sign = 'range';
	$m_defer_net = 1;

	$m_search_form_show = 0;
	$m_records_show = 1;
	$m_ai_show = 1;
	$m_go_show = 0;

	$s_search_author = '';
	$s_search_source = '';
	$s_search_tiword = '';
	$s_search_pubyear = '';
}

sub s_sets_init {
	$VIEW = 'base';
	$DO_WD = 1; $DO_WD_OLD = 0;
	$DO_OR = 1; $DO_OR_OLD = 0;
	$DO_ML = 0; $DO_ML_OLD = 0;
	$bcut_years = 3; $ecut_years = 3;
	$MAIN_TI = 10;
	$MAIN_PI = 100;
	$REC_SHOW = 'full';
	$HIL_SHOW = 1;
	$HIX_SHOW = 1;
	$HIG_SHOW = 1;
	$HIS_SHOW = 1;
	$AU_TI = 30;
	$AU_PI = 200;
	$FONT_SIZE = '10';
	$CI_authors = 5;
	$DO_CI_au_cut = 1;
	$CI_patents = 3;
	$DO_CI_pn_cut = 1;
	$DO_PAGE_INDX = 0;
	$DO_PAGE_EXT = 0;
	$DO_SAVE_GM_SETS = 0;

	$DO_USE_WD_TI = 1;
	$DO_USE_STOPWD = 1;
	$DO_SPLIT_DASH = 1;
	$SMALL_WORD = 2;
	$DO_USE_WD_DE = 0;
	$DO_USE_WD_ID = 0;
	$DO_KEY_SPLIT_WORDS = 1;
	$DO_KEY_SPLIT_DASH = 0;
	$DO_WD_KEY_SHOW = 1;
	$DO_WD_UPPER = 1;

	$WOS_GW ||= 0;	#0 - SFX, 1 - WoK4, 2 - WoK3
	$WOS_LOC4 ||= '';
	$WOS_SID = '';

	$USE_RP = 1;	#2 - Always, 1 - Only if no cs, 0 - Never

	$TipOnStart ||= 1;
	s_html_init();
}

sub s_html_init {
	$HTML_LIMITS = 1;
	$HTML_LCS = 20;
	$HTML_GCS = 100;
	$HTMLPAGE = 2;
	$HTML_TL2 = 1;
	$HTMLPUBS = 40;
	$LISTN = 20;
}

sub s_sets_set {
	my $q = shift;
	my $set = shift||'';

	$DO_WD_OLD = $DO_WD;
	$DO_OR_OLD = $DO_OR;
	$DO_ML_OLD = $DO_ML;
	my %addr = qw(in 1 i2 1 co 1);
	my @m_wd = qw(USE_WD_TI USE_STOPWD SPLIT_DASH USE_WD_DE USE_WD_ID KEY_SPLIT_WORDS KEY_SPLIT_DASH WD_UPPER WD_KEY_SHOW);
	my @m;
	if('wd' eq $set) {
		@m = @m_wd;
	} elsif('or' eq $set or $addr{$set} or 'html' eq $set) {
		@m = ();
	} else {
		@m = (qw(WD OR ML PAGE_INDX PAGE_EXT SAVE_GM_SETS CI_au_cut CI_pn_cut), @m_wd);
	}
	if('wd' eq $set or not $set) {
		$DO_USE_WD_TI_OLD = $DO_USE_WD_TI; $DO_USE_WD_DE_OLD = $DO_USE_WD_DE; $DO_USE_WD_ID_OLD = $DO_USE_WD_ID;
		$DO_USE_STOPWD_OLD = $DO_USE_STOPWD; $SMALL_WORD_OLD = $SMALL_WORD; $DO_SPLIT_DASH_OLD = $DO_SPLIT_DASH;
		$DO_KEY_SPLIT_WORDS_OLD = $DO_KEY_SPLIT_WORDS; $DO_KEY_SPLIT_DASH_OLD = $DO_KEY_SPLIT_DASH;
	}
	for my $m (@m) {
		eval "\$DO_$m = (\$q->param('$m') ? 1 : 0)";
	}
	if(!$DO_USE_WD_TI) {
		$DO_USE_STOPWD = $DO_USE_STOPWD_OLD;
		$DO_SPLIT_DASH = $DO_SPLIT_DASH_OLD;
	}
	if(!$DO_USE_WD_DE && !$DO_USE_WD_ID) {
		$DO_KEY_SPLIT_WORDS = $DO_KEY_SPLIT_WORDS_OLD;
		$DO_KEY_SPLIT_DASH = $DO_KEY_SPLIT_DASH_OLD;
	}

	$VIEW = $q->param('VIEW') if $q->param('VIEW');
	if(not $set) {
		$bcut_years_old = $bcut_years;
		$ecut_years_old = $ecut_years;
		my $year_b = $q->param('YEAR_B')||3;
		$bcut_years = $year_b if $year_b =~ /^\d+$/ ;
		my $year_e = $q->param('YEAR_E')||3;
		$ecut_years = $year_e if $year_e =~ /^\d+$/ ;
		if($bcut_years_old <=> $bcut_years or
			($ecut_years_old <=> $ecut_years)) {
			calc_lcs_cuts();
		}
	}

	my(@seti, @setchk) = ((),());
	if('wd' eq $set) {
		@seti = qw(SMALL_WORD);
	} elsif('or' eq $set or $addr{$set}) {
		@seti = ();
	} elsif('html' eq $set) {
		@seti = qw(HTML_LCS HTML_GCS HTMLPUBS LISTN HTMLPAGE);
		@setchk = qw(HTML_LIMITS HTML_TL2);
	} else {
		@seti = qw(MAIN_TI MAIN_PI AU_TI AU_PI SMALL_WORD CI_authors CI_patents HTML_LCS HTML_GCS HTMLPUBS LISTN HTMLPAGE FONT_SIZE);
		@setchk = qw(HTML_LIMITS HTML_TL2 TipOnStart);
	}
	my %zero_ok = qw(SMALL_WORD 1 HTML_LCS 1 HTML_GCS 1);
	for my $seti (@seti) {
		my $s = defined $q->param($seti) ? $q->param($seti) : '';
		next unless $s =~ /^\d+$/;
		eval "\$$seti = $s" if $s > 0 or $zero_ok{$seti};
	}
	for my $chk (@setchk) {
		eval "\$$chk = \$q->param('$chk')||0";
	}

	if('or' eq $set or not $set) {
		$WOS_GW = $q->param('WOS_GW');
		$WOS_LOC4 = $q->param('wos_loc4');
		$WOS_SID = $q->param('wos_sid');
	}
	if('wd' eq $set or not $set) {
		if($DO_WD and ( $DO_USE_STOPWD_OLD <=> $DO_USE_STOPWD or $DO_SPLIT_DASH_OLD <=> $DO_SPLIT_DASH
			or $DO_USE_WD_TI_OLD <=> $DO_USE_WD_TI or $DO_USE_WD_DE_OLD <=> $DO_USE_WD_DE or $DO_USE_WD_ID_OLD <=> $DO_USE_WD_ID
			or $DO_KEY_SPLIT_WORDS_OLD <=> $DO_KEY_SPLIT_WORDS or $DO_KEY_SPLIT_DASH_OLD <=> $DO_KEY_SPLIT_DASH
			or $SMALL_WORD_OLD <=> $SMALL_WORD)) {
			$DO_WD_OLD = 0;
			$dirty{wd} = 1;
		}
	}
	if($addr{$set} or not $set) {
		my $addr_changed = 0;
		my $addr_old = $USE_RP;
		$USE_RP = $q->param('USE_RP');
		$addr_changed = 1 if $addr_old != $USE_RP;
		if('co' eq $set or not $set) {
			my $changed = 0;
			for my $u (keys %unite) {
				my $old = $unite{$u}{on};
				$unite{$u}{on} = ($q->param($u) ? 1 : 0);
				$changed = 1 if $old != $unite{$u}{on};
			}
			if($changed or $addr_changed) {
				init_unions() if $changed;
				for my $n (@tl) {
					$hra->{$n}->{co} = join "\n", $extractor{co}->($n);
				}
				$dirty{co} = 1;
			}
		}
		if($addr_changed) {
			for my $n (@tl) {
				$hra->{$n}->{in} = join "\n", $extractor{in}->($n);
				$hra->{$n}->{i2} = join "\n", $extractor{i2}->($n);
			}
			$dirty{in} = $dirty{i2} = 1;
		}
	}

	do_modules(1);
	if(not $set) {
		$DO_WD_OLD = 0;
		$DO_OR_OLD = 0;
		$DO_ML_OLD = 0;
	}
}

sub props_set {
	my $q = shift;
	$NEEDSAVE = 1 if $$title_line ne $q->param('title')
		or $$caption ne $q->param('caption')
		or $MORIGINAL ne $q->param('moriginal')
		or $MNB ne $q->param('comment');
	$$title_line = $q->param('title');
	$$caption = $q->param('caption');
	$MNB = $q->param('comment');
	$MORIGINAL = $q->param('moriginal');
}

sub do_prepare_histograms {
#	%higram = map { ($_, {('enabled', 1)}) } keys %f_ful unless defined %higram;
#d tagged for deprecation, used for 'py' only for now
	%higram = ('py' => {('enabled', 1)}) unless (%higram);
	return if not $DIRTY_CHARTS;
	my %list_cont = qw(in 1 in2 1 co 1);
	for my $k (keys %higram) {
		$higram{$k}->{item} = {};
		if($list_cont{$k}){
			$higram{$k}->{only} = {};
			$higram{$k}->{many} = {};
		}
	}

	my $t = time;
	print LOG "Preparing histograms..";
	my @fi = ();
	for $k (keys %higram) {
		push @fi, $k if $higram{$k}->{enabled};
	}
	my %extractor = ();
	$extractor{in} = sub { return extract_from_list(@_) };
	$extractor{in2} = sub { return extract_from_list(@_, 2) };
	$extractor{co} = sub { return extract_country_from_list(@_) };
	for $r (@tl) {
		for $fi (@fi) {
			my $key;
			if($list_cont{$fi}) {
				my $only_key = ''; my $i = 0;
				my %many = ();
				for $f ($extractor{$fi}->($r)) {
					$key = uc $f;
					$many{$key} = 1;
					if($i and $only_key ne $key) {
						$only_key = '';
					} else {
						$only_key = $key;
					}
					++$higram{$fi}->{item}{$key}{n};
					$higram{$fi}->{item}{$key}{name} = $f;
					push2str \$higram{$fi}->{item}{$key}{nodes} , $hra->{$r}->{tl};
					if(-1 < $hra->{$r}->{tc}) {
						$higram{$fi}->{item}{$key}{gcs} += $hra->{$r}->{tc};
						$higram{$fi}->{item}{$key}{gcs2} += $hra->{$r}->{tc}**2;
					}
					++$i;
				}
##			$au{$AU}->{lcs} += $#{$pub->{cited}} + 1;
				if($only_key) {
					$higram{$fi}->{only}{$key}{name} = $key;
					++$higram{$fi}->{only}{$only_key}{n};
					push2str \$higram{$fi}->{only}{$only_key}{nodes} , $hra->{$r}->{tl};
					if(-1 < $hra->{$r}->{tc}) {
						$higram{$fi}->{only}{$only_key}{gcs} += $hra->{$r}->{tc};
						$higram{$fi}->{only}{$only_key}{gcs2} += $hra->{$r}->{tc}**2;
					}
				} else {
					for my $ki (keys %many) {
						$higram{$fi}->{many}{$ki}{name} = $ki;
						push2str \$higram{$fi}->{many}{$ki}{nodes} , $hra->{$r}->{tl};
						if(-1 < $hra->{$r}->{tc}) {
							$higram{$fi}->{many}{$ki}{gcs} += $hra->{$r}->{tc};
							$higram{$fi}->{many}{$ki}{gcs2} += $hra->{$r}->{tc}**2;
						}
					}
				}
			} else {
				my $f = ($hra->{$r}->{$fi} ? $hra->{$r}->{$fi} : 'Unknown');
				$f = ($pt{$f} ? $pt{$f} : $f);
				$key = uc $f;
				++$higram{$fi}->{item}{$key}{n};
				$higram{$fi}->{item}{$key}{name} = $f;
				$higram{$fi}->{item}{$key}->{name} = $f;
				push2str \$higram{$fi}->{item}{$key}{nodes} , $hra->{$r}->{tl};
				if(-1 < $hra->{$r}->{tc}) {
					$higram{$fi}->{item}{$key}{gcs} += $hra->{$r}->{tc};
#					$higram{$fi}->{many}{$ki}{gcs2} += $hra->{$r}->{tc}**2;
				}
			}
			$higram{$fi}->{item}{$key}{lcs} += $hra->{$r}->{lcs};
			++$higram{$fi}->{item}{$key}{pubs};
		}
	}
	if(0 < $#tl) {
		for $f ($net_first_year..$net_last_year) {
			$higram{py}->{item}{$f}{name} = $f;
		}
	}
	for $fi (@fi) {
		$higram{$fi}->{index} = [ sort {$a cmp $b} keys %{ $higram{$fi}->{item} } ];
		my $i = 0;
		for $k (@{ $higram{$fi}->{index} }) {
			$higram{$fi}->{only}{$k}{i} = $i if $list_cont{$fi};
			$higram{$fi}->{many}{$k}{i} = $i if $list_cont{$fi};
			$higram{$fi}->{item}{$k}{i} = $i++;
			$higram{$fi}->{item}{$k}{gcs} = -1 unless defined $higram{$fi}->{item}{$k}{gcs};
		}
	}
	do_done($t);
	$DIRTY_CHARTS = 0;
}

sub histogram_as_html {
#d tagged for deprecation, used for 'py' only for now
# but need to transfer only/many categories first....
	my $fi = shift;
	my $final = shift;
	do_prepare_histograms();
	return histogram_X_as_html('py', $final) if 'pyX' eq $fi;
	my %list_cont = qw(in 1 in2 1 co 1);

	my $o = "<TITLE>HistCite - $$title</TITLE>\n";
	add_body_script(\$o);
$o .= <<"";
<STYLE type="text/css">
th,td {
	white-space: nowrap;
}
.wrap {
	white-space: normal;
}
.bar { background-color: #000; line-height: 8px; margin: 2px 0 0 4px; font-size: 6px; }
</STYLE>

	add_toggle_script(\$o) if('bibl' eq $VIEW and $list_cont{$fi});

	$o .= "<TABLE width=100% cellpadding=0 cellspacing=0><TR><TD align=left>";
#	$o .= "<a href=list.html style=text-decoration:none; title='List of graphs'>Graphs</a>&nbsp;&nbsp;";
	$o .= 'Yearly Output histogram&nbsp;&nbsp;';
	add_close_link(\$o);
	$o .= "<TD align=right>";
	if('co' eq $fi) {
		$o .= "<a href=# OnClick=\"window.open('/settings/co','settings','width=480,height=480,resizable=yes,scrollbars=yes,status=yes')\">Settings</a>&nbsp;&nbsp;\n"
			if $LIVE;
		$o .= window_help('../help/co.html');
	}
	$o .= "</TABLE>\n";

	my $hr = $higram{$fi}->{item};
	my $hro = $higram{$fi}->{only};
	my $hrm = $higram{$fi}->{many};
	my $N = $#tl + 1;
	$o .= "Number of records: $N";
#d	$o .= ",\n<a href=# OnClick=\"window.open('/mark/index.html','mn',$win_opts)\">Marks</a>: $MARKS" if $LIVE;
	$o .= "<p>\n";

	my($min,$max);
	$min = $#tl + 1; $max = 0;
	for $k (keys %{ $hr }) {
		my $v = $hr->{$k}{n} || 0;
		$min = ($v < $min ? $v : $min);
		$max = ($v > $max ? $v : $max);
	}
	my $USE_PERCENT = 1 if 200 < $max;

	my $SCALE = 1;
	if($USE_PERCENT) {
		$o .= "Bar charts are proportional to percentage, and scaled.";
		$SCALE = 100 / ($max / $N * 100) if $max;
	} else {
		$o .= "Bar charts are proportional to record count, and scaled.";
		$SCALE = 100 / $max if $max;
	}

	my @range;
	if('py' eq $fi) {
		@range = sort {uc $a cmp uc $b} keys %{ $hr };
	} else {
		@range = sort {
			if($hr->{$b}{n} == $hr->{$a}{n}) {
				$a cmp $b
			} else {
				$hr->{$b}{n} <=> $hr->{$a}{n}
			}
		} keys %{ $hr };
		$o .= "<br>Items are sorted by frequency.\n";
	}
	$o .= '<TABLE border=0 cellpadding=0 cellspacing=0><TR valign=top><TD>';
	$o .= '<TD>';
	$o .= <<"" if('bibl' eq $VIEW and $list_cont{$fi});
&nbsp;&nbsp;<TD>
<a href="javascript:toggle('means')" style="text-decoration:none;"><div id=mmeans>Show Explanation</div><div id=lmeans style=display:none>Hide Explanation</div></a>

	$o .= '</TABLE>';
	$o .= <<"" if('bibl' eq $VIEW and $list_cont{$fi});
<table id="means" style="display:none"><tr><td class="wrap">
Each category is considered to consist of two subcategories.
First comprises publications from the given category exclusively.
Second includes publications that fall into other categories as well.
<br>As such, 
<b>Count</b> contains three numbers, corresponding to each subcategory, 
and the whole category.
<br><b>Percent</b> contains five numbers.  First two are the relation between
each subcategory to the whole category count.
The other three are percentages of each 
count to total number of all publications.
<br>When counts for both subcategories are nonezero the bar chart is
divided in two to reflect each subcategory's share.
<br><b>Mean GCS</b> and corresponding <b>SE</b> (Standard Error) are
computed for each subcategory.
<br>Respective <b>Percent SE</b> are also printed.
<br>(N.B. Mean GCS and SE are currently computed with respect to all 
values.  In other words, "missed" values, if any, are included as zeros.)
</table>

#d	$o .= '<FORM method=POST name=t>' if $LIVE;
	$o .= "<TABLE cellpadding=3>\n";
	$o .= "<TR><TH nowrap>$f_ful{$fi}<TH>Count<TH";
	if('bibl' eq $VIEW and $list_cont{$fi}) {
		$o .= ' colspan=2';
	}
	$o .= ">Percent<TH>&nbsp;\n";
	if('bibl' eq $VIEW and $list_cont{$fi}) {
		$o .= "<TH><TH>mean GCS<TH>|<TH>SE<TH>|<TH colspan=2>Percent SE\n";
	}

	my($count, $only_count, $many_count, $percent, $only_percent, $many_percent, $scale, $only_scale, $width, $only_width);
	my $i = 0;
	for my $f (@range) {
		$o .= '<TR align=right><TD align=left nowrap>';
#d		$o .= "<INPUT name=node type=checkbox value=$i> " if $LIVE;
		++$i;
		$o .= "$hr->{$f}{name}<TD>";

	#	$o .= lister_link('', $hr->{$f}{i}, $count) if 1 < $count;

		my @nodes = (defined $hr->{$f}->{nodes} ? eval $hr->{$f}->{nodes} : () );
		my @nodeso = (defined $hro->{$f}->{nodes} ? eval $hro->{$f}->{nodes} : () );
		my @nodesm = (defined $hrm->{$f}->{nodes} ? eval $hrm->{$f}->{nodes} : () );
		$count = ($hr->{$f}{n} ? $hr->{$f}{n} : 0);
		$only_count = ($hro->{$f}{n} ? $hro->{$f}{n} : 0);
		$many_count = $count - $only_count;

		if('bibl' eq $VIEW and $list_cont{$fi}) {
			if($final) {
				$o .= $only_count;
			} else {
				$o .= list_data($only_count, undef, $nodeso[0], $hro->{$f}{i}, undef,
					'', "graph/only/$fi",  $f, $hro, 1);
			}
			$o .= ' + ';
			if($final) {
				$o .= $many_count;
			} else {
				$o .= list_data($many_count, undef, $nodesm[0], $hrm->{$f}{i}, undef,
					'', "graph/many/$fi",  $f, $hrm, 1);
			}
			$o .= ' = ';
		}
		$o .= $count;
#d		$o .= list_data($count, undef, $nodes[0], $hr->{$f}{i}, undef,
#d			$final, "graph/$fi",  $f, $hr, 1);

		my($sub_percent, $sub2_percent);
		if('bibl' eq $VIEW and $list_cont{$fi}) {
			$sub_percent = $only_count / $count * 100;
			$sub2_percent = 100 - $sub_percent;
			$o .= '<TD>&nbsp;'. nbsp($sub_percent, 1) .' + '. nbsp($sub2_percent, 1);
		}
		$percent = $count / $N * 100;
		$only_percent = $only_count / $N * 100;
		$many_percent = $percent - $only_percent;
		$o .= '<TD>&nbsp;';
		if('bibl' eq $VIEW and $list_cont{$fi}) {
			$o .= nbsp($only_percent, 1) .' + '. nbsp($many_percent, 1) .' = ';
		}
		$o .= nbsp($percent, 1);

		$scale = ($USE_PERCENT ? $percent : $count);
		$only_scale = ($USE_PERCENT ? $only_percent : $only_count);
		$width = 2 * $scale * $SCALE;
		$only_width = 2 * $only_scale * $SCALE;
		do { use integer; $width += 0; $width = 1 if 0 == $width and $count > 0; };
		do { use integer; $only_width += 0;
			$only_width = 1 if 0 == $only_width and $only_count > 0; };
		$o .= "<TD align=left>";
		if('bibl' eq $VIEW and $list_cont{$fi}) {
			my $many_width = $width - $only_width;
			$o .= "<IMG SRC=../black.jpg height=7 width=$only_width>" if $only_width;
			$o .= "<IMG SRC=../non.jpg height=7 width=1>" if $only_width and $many_width;
			$o .= "<IMG SRC=../black.jpg height=7 width=$many_width>" if $many_width;
		} else {
			$o .= "<div class=bar style=width:${width}px;>.</div>" if $count;;
		}
		$o .= "\n";

		#mean GCS, SE
		#M = Sum(x_i) / N;    SE = sqrt( (Sum[x_i^2] - (Sum[x_i])^2 / N) / (N-1)*N )
		if('bibl' eq $VIEW and $list_cont{$fi}) {
			my $no = $only_count;
			my $nm = $many_count;
			my $n = $count;
			$o .= '<TD>&nbsp;<TD>';
			my $tgcso = $hro->{$f}{gcs} ? $hro->{$f}{gcs} : 0;
			$o .= $no ? nbsp($tgcso/$no, 2) : 'na';
			$o .= ' | ';
			my $tgcsm = $hrm->{$f}{gcs} ? $hrm->{$f}{gcs} : 0;
			$o .= $nm ? nbsp($tgcsm/$nm, 2) : 'na';
			$o .= ' / '. nbsp($hr->{$f}{gcs}/$n, 2);

			$o .= '<TD>&nbsp;<TD>';
			$o .= $no > 1 ? nbsp(sqrt( ($hro->{$f}{gcs2} - $hro->{$f}{gcs}**2/$no)/(($no-1)*$no)), 2) : 'na';
			$o .= ' | ';
			$o .= $nm > 1 ? nbsp(sqrt( ($hrm->{$f}{gcs2} - $hrm->{$f}{gcs}**2/$nm)/(($nm-1)*$nm)), 2) : 'na';
			$o .= ' / ';
			$o .= $n > 1 ? nbsp(sqrt( ($hr->{$f}{gcs2} - $hr->{$f}{gcs}**2/$n)/(($n-1)*$n)), 2) : 'na';

			#Percent SE; SE(P) = sqrt( (100-P)*P / N )
			$o .= '<TD>&nbsp;<TD>';
			$o .= nbsp(sqrt((100-$sub_percent)*$sub_percent/$n), 2) if $no;
			$o .= ' | ';
			$o .= nbsp(sqrt((100-$sub2_percent)*$sub2_percent/$n), 2) if $nm;
			$o .= '<TD>&nbsp;&nbsp;';
			$o .= nbsp(sqrt((100-$only_percent)*$only_percent/$N), 2) if $no;
			$o .= ' | ';
			$o .= nbsp(sqrt((100-$many_percent)*$many_percent/$N), 2) if $nm;
			$o .= ' / ';
			$o .= nbsp(sqrt((100-$percent)*$percent/$N), 2);
			$o .= "\n";
		}
	}
	$o .= '</TABLE>';
	if($LIVE and 'bibl' eq $VIEW and $list_cont{$fi}) {
		$o .= <<"";
Apply the action below to:<br>
<INPUT type=radio name=range value=all ${\('all' eq $m_sets_histo_range ? 'CHECKED' : '')}> whole category<br>
<INPUT type=radio name=range value=only ${\('only' eq $m_sets_histo_range ? 'CHECKED' : '')}> exclusive subcategory<br>
<INPUT type=radio name=range value=shared ${\('shared' eq $m_sets_histo_range ? 'CHECKED' : '')}> shared subcategory<br>

	}

	$o .= "<p>Items: ". ($#range + 1);
	$o .= "</BODY>";

	return $o;
}

sub histogram_X_as_html {
	my $fi = shift;
	my $final = shift;
	my $o = "<TITLE>HistCite - $f_ful{$fi}: $$title</TITLE>\n";
	$o .= "<BODY VLINK=blue OnLoad=\"focus()\">\n";
	$o .= "<SCRIPT>function opeNod (a) { opener.top.opeNod(a); } </SCRIPT>";
	$o .= "<SCRIPT>function opeLod (d, a) { opener.top.opeLod('graph/$fi', a); } </SCRIPT>";
	$o .= "<a href=list.html style=text-decoration:none;>Graphs</a><p>\n";

	my $hr = $higram{$fi}->{item};
	my $N = $#tl + 1;
	$o .= "Number of publications: $N<p>\n";

	my($min,$max);
	$min = $#tl + 1; $max = 0;
	for $k (keys %{ $hr }) {
		my $v = $hr->{$k}{n} || 0;
		$min = ($v < $min ? $v : $min);
		$max = ($v > $max ? $v : $max);
	}
	my $USE_PERCENT = 1 if 200 < $max;

	my $SCALE = 1;
	if($USE_PERCENT) {
		$o .= "Bar charts are proportional to percentage, and scaled.";
		$SCALE = 100 / ($max / $N * 100);
	} else {
		$o .= "Bar charts are proportional to record count, and scaled.";
		$SCALE = 100 / $max;
	}

	my @range;
	if('py' eq $fi) {
		@range = sort {uc $a cmp uc $b} keys %{ $hr };
	} else {
		@range = sort {
			if($hr->{$b}{n} == $hr->{$a}{n}) {
				$a cmp $b
			} else {
				$hr->{$b}{n} <=> $hr->{$a}{n}
			}
		} keys %{ $hr };
		$o .= "<br>Items are sorted by frequency.";
	}

	$o .= "<p>\n";
	$o .= "<TABLE cellpadding=1>\n";

	my(@count, @percent, $scale, $width);
	my @node;

	$o .= "<TR valign=bottom align=center><TH>&nbsp;";
	for $f (@range) {
		my @nodes = (defined $hr->{$f}->{nodes} ? eval $hr->{$f}->{nodes} : () );
		push @node, $nodes[0];
		push @count, ($hr->{$f}{n} ? $hr->{$f}{n} : 0);
		push @percent, $count[$#count] / $N * 100;
		$scale = ($USE_PERCENT ? $percent[$#percent] : $count[$#count]);
		$width = 2 * $scale * $SCALE;
		do { use integer; $width += 0; $width = 1 if 0 == $width and $count[$#count] > 0; };
		$o .= "<TD>";
		$o .= "<IMG SRC=../black.jpg width=7 height=$width>\n" 
			if 0 < $count[$#count];
	}
	my $font_size = -2;
	$o .= "<TR align=right><TH><FONT SIZE=$font_size>Percent</FONT>";
	for $p (@percent) {
		$o .= '<TD>';
		$o .= "<FONT SIZE=$font_size>";
		$o .= nbsp($p, 1);
		$o .= '</FONT>';
	}
	$o .= "<TR align=right><TH><FONT SIZE=$font_size>Count</FONT>";
	my $i = 0;
	for $c (@count) {
		my $f = $range[$i];
		$o .= "<TD>";
		$o .= "<FONT SIZE=$font_size>";
		$o .= list_data($c, undef, $node[$i], $hr->{$f}{i}, undef,
			$final, "graph/$fi",  $f, $hr);
		$o .= '</FONT>';
		++$i;
	}
	$o .= "<TR align=right><TH nowrap><FONT SIZE=$font_size>$f_ful{$fi}</FONT>";
	for $f (@range) {
		$o .= "<TD nowrap>";
		$o .= "<FONT SIZE=$font_size>";
		$o .= $hr->{$f}{name};
		$o .= '</FONT>';
	}
	$o .= "</TABLE>";

	$o .= "<p>Items: ". ($#range + 1);
	$o .= "</BODY>";

	return $o;
}

sub extract_from_list {
	my $rid = shift;
	my $n = shift||1;
	--$n;
	my %h;
	my $pub = $hra->{$rid};
	my @li = split /\n/, $pub->{cs};
	if($pub->{rp} and (!@li && $USE_RP or 2 == $USE_RP) ) {
		my $li = $pub->{rp};
		$li =~ s/\n +/ /g;
		$li =~ s/;/,/;	#Scopus
		$li =~ s/^[\w' -]+, [\w.]+, //;	#Szava-Kovats, E | . Scopus
##		$li =~ s/^.+;//;	#Scopus
		push @li, $li;
	}
	local $" = ', ';
	for my $li (@li) {
		next if not $li =~ /,/;
		$li =~ s/\[.+\] //;
		my @f = split /,/, $li;
		@f = map trim($_), @f;
		my $N = (3 >= @f ? 0 : $n);	#no subdivision given
		my $ext = "@f[0 .. $N]";
		$h{$ext} = 1;
	}
	my @test = keys %h;
	$h{'Unknown'} = 1 if 0 == @test;
	return keys %h;
}

sub extract_country_from_list {
	my $rid = shift;
	my %h;
	my $pub = $hra->{$rid};
	my @li = split /\n/, $pub->{cs};
	if($pub->{rp} and (!@li && $USE_RP or 2 == $USE_RP) ) {
		my $li = $pub->{rp};
		$li =~ s/\n +/ /g;
		$li =~ s/;/,/;	#Scopus
		push @li, $li;
	}
	for my $li (@li) {
		$li =~ s/\W+$//;
		my @f = split /,/, $li;
		next if 4 > @f;	#Scopus for sure
		my $ext = $f[$#f];
		$ext =~ s/^\s+//;
		if($ext =~ /^\w\w \d{5}$/ or $ext =~ / USA$/ or $state{$ext}) {
			$ext = 'USA';
		} elsif($union{uc $ext}) {
			$ext = $union{uc $ext};
		}
		$h{$ext} = 1;
	}
	my @test = keys %h;
	$h{'Unknown'} = 1 if 0 > $#test;
	return keys %h;
}

sub a2graph {
	my $hr = $hra;

	print LOG "Making graph..";
	delete $gc->{img} if $gc;
	my $nod = {shape => $g_node_shape, fontsize => $g_nodes_font, fixedsize => 'true'};
	my $edg = {arrowsize => $g_arrowsize};
	if('backward' eq $g_arrowdir) {
		$edg->{arrowhead} = 'none'; $edg->{arrowtail} = $g_arrowtype;
	} else {
		$edg->{arrowtail} = 'none'; $edg->{arrowhead} = $g_arrowtype;
	}
	my $ranksep = $g_ranksep;
#	$ranksep .= ' equally' if $g_equally; #next time

	my @size = ();
	my @size_ps = (pagewidth => 8.5, pageheight => 11);
	if(1==$g_size) {	# Letter
		@size = (width => 6.5, height => 9);
		push @size_ps, (width => 7.5, height => 10);
	} elsif(2==$g_size) {	# window
		@size = (width => ($g_size_width-20)/96, height => ($g_size_height-25)/96);
		push @size_ps, @size;
	}

	$gc->{img} = HC::Graphviz->new(ranksep => $ranksep, node => $nod, @size,
		edge => $edg, concentrate => $g_concentrate, nodesep => $g_nodesep);
	$gc->{ps} = HC::Graphviz->new(ranksep => $ranksep, node => $nod, @size_ps,
		edge => $edg, concentrate => $g_concentrate, nodesep => $g_nodesep);

	my %year_count = ();
	my %map_node = ();
	my $cs_max = 0; my $cs_min = 4294967296;
	my $year_max = 0; my $year_min = 3000;
	my $what = ($g_use_lcs ? 'lcs' : 'tc');
	my $count = 0;
	#select nodes to %map_node according to criteria
	#prepare timeline for ranking
	do { for my $rid ($sorted_by{$what}->($hr)) {
		my $pub = $hr->{$rid};
		++$year_count{$pub->{py}}->{count};
		my $cs = get_cs($hr, $rid, $g_use_lcs);
		if(($g_use_val and $g_limit <= $cs) 
		or (!$g_use_val and $count < $g_limit)) {
			$map_node{$pub->{tl}} = 1;
			my $py = $pub->{py};
			$year_count{$py}->{show} = 1;
			$year_count{$py}->{pdm}{0} = '';
			if($g_monthly) {
				$year_count{$py}->{pdm}{$pub->{pdm}} = '';
			}
			$cs_max = $cs if $cs > $cs_max;
			$cs_min = $cs if $cs < $cs_min;
			$year_max = $py if $py > $year_max;
			$year_min = $py if $py < $year_min;
		}
		++$count;
	} } if $g_select;

	do { while( my ($rid, $v) = each %{ $hrm } ) {
		my $pub = $hr->{$rid};
		++$year_count{$pub->{py}}->{count};
		my $cs = get_cs($hr, $rid, $g_use_lcs);
		$map_node{$pub->{tl}} = 1;
		my $py = $pub->{py};
		$year_count{$py}->{show} = 1;
		$year_count{$py}->{pdm}{0} = '';
		if($g_monthly) {
			$year_count{$py}->{pdm}{$pub->{pdm}} = '';
		}
		$cs_max = $cs if $cs > $cs_max;
		$cs_min = $cs if $cs < $cs_min;
		$year_max = $py if $py > $year_max;
		$year_min = $py if $py < $year_min;
		++$count;
	} } if $g_marks;

	if($g_gap_years) {
		for my $py ($year_min .. $year_max) {
			$year_count{$py}->{count} ||= 0;
			$year_count{$py}->{show} = 1;
			$year_count{$py}->{pdm}{0} = '';
		}
	}

	my $scale = .5625;	#.75**2
	$scale /= $cs_max if 0 < $cs_max;
	my @py;
	for my $py (sort keys %year_count) {
		if(exists $year_count{$py}->{show}) {
			for my $m (sort {$a <=> $b} keys %{$year_count{$py}->{pdm}}) {
				push @py, [($py, $m)];
			}
		}
	}

	my $color = 'white';
	my $style = 'invis';
	for(my $y = 0; $y <= $#py; ) {
		my ($date, $label, $py, $pdm, $fontsize);
		$py = $py[$y][0];
		$pdm = $py[$y][1];
		$date = "$py$mon[$pdm]";
		if(0 == $pdm) {
			$label = $py . ($g_yearcount ? " ($year_count{$py}->{count})" : '');
			$fontsize = $g_years_font;
		} else {
			$label = $mon[$pdm];
			$fontsize = $g_month_font;
		}
		#1 point [Britain, US] = 0.0137795 inch [international, U.S.]
		#http://www.onlineconversion.com/length_all.htm
		# 1 PostScript point =  0.01388888 inch
		#http://www.prepressure.com/library/didot.htm
		my $height = .0139 * (2 + $fontsize);
		my $width = .01388888 * (2 + length($label)/1.5 * $fontsize);
		for my $f qw(img ps) {
			$gc->{$f}->add_node("y$date", label => $label, fontsize => $fontsize,
				shape => 'plaintext', rank => $date, height => $height, width => $width,
				margin => 0);
		}
		++$y;
		if($y <= $#py) {
			for my $f qw(img ps) {
				$gc->{$f}->add_edge("y$date" => "y$py[$y][0]$mon[$py[$y][1]]",
					arrowhead => 'normal', arrowtail => 'none',
					color => $color, style => $style);
			}
		}
	}

	my $side = $g_fixed_size;
	$gc->{nodes} = 0;
	$gc->{edges} = 0;
	for my $tl (keys %map_node) {
		my $ci = $tl[$tl];
		my $py = $hr->{$ci}->{py};
		my $date;

		my $cs = get_cs($hr, $ci, $g_use_lcs);
		my $n = $hr->{$ci}->{tl};
		if('plaintext' ne $g_node_shape and $g_node_scaled) {
			$side = $g_scale_factor * sqrt($cs * $scale);
			$side = .1 if .1 > $side;
		}
		my $label = '';
		if('inside' eq $g_node_label_loc) {
			$label = ($n + 1);
		}
		my $style = (0 == $cs ? 'filled' : '');
		if($g_monthly) { $date = "$py$mon[$hr->{$ci}->{pdm}]" }
		else { $date = $py }

		for my $f qw(img ps) {
			$gc->{$f}->add_node("n$n", label => $label, height => $side,
				width => $side, rank => $date, URL => $n, style => $style );
		}

		if('outside' eq $g_node_label_loc) {
			for my $f qw(img ps) {
				$gc->{$f}->add_edge("n$n" => "n$n", headlabel => 1+$n,
					color => 'white', arrowhead => 'none',
					labelfontsize => $g_nodes_font, labeldistance => $g_label_dist);
			}
		}
		++$gc->{nodes};

		if($g_connected) {
			for my $c (@{$hr->{$ci}->{cited}}) {
				if($map_node{$c}) {
					for my $f qw(img ps) {
						$gc->{$f}->add_edge("n$n" => "n$c");
					}
					++$gc->{edges};
				}
			}
		}
	}
	$gc->{nodel} = join ',', (keys %map_node);

	my $info = "Nodes: $gc->{nodes}";
	$info .= ", Links: $gc->{edges}" if $gc->{edges};
	my $inf2 = '';
	if($g_select) {
		$inf2 .= ($g_use_lcs ? 'LCS' : 'GCS' );
		$inf2 .= ($g_use_val ? ' >= ' : ', top ' );
		$inf2 .= "$g_limit; ";
	}
	if($g_marks) {
		$inf2 .= " $MARKS marks; ";
	}
	if($gc->{nodes}) {
		$inf2 .= "Min: $cs_min, Max: $cs_max";
		$inf2 .= ' ('. ($g_use_lcs ? 'LCS' : 'GCS' ) .' scaled)';
	}
	print LOG "($info ($inf2))\n";

	if($g_mk_info) {
		$gc->{info} = $info;
		$gc->{inf2} = $inf2;
	} else {
		$gc->{info} = '';
		$gc->{inf2} = '';
	}
	$gc->{legend} = '';
	if($g_mk_legend && $gc->{nodes}) {
		local $VIEW = 'bibl';
		local $LIVE = 0;
		local %on_kept_graph = %map_node;
		my $j = 0;
		$gc->{legend} = '<TABLE><TR><td><td><td><td>LCS<td>GCS'
			unless $g_legend_full;
		for my $i (sort {$a <=> $b} (keys %map_node)) {
			++$j;
			if($g_legend_full) {
				$gc->{legend} .= "<br><br>$j. ". ${ citation2html($i) };
			} else {
				my $r = brief_citation($i, 1);
				$r =~ s/ LCS:/<TD>/;
				$r =~ s/ GCS:/<TD>/;
				$gc->{legend} .= "<TR align=right valign=top><TD>$j. <TD><a href=#";
				my $pub = $hra->{$tl[$i]};
				my $ti = $pub->{dt} ? " $pub->{dt} " : 'Unknown document type';
				$gc->{legend} .= qq( TITLE="$ti");
				$gc->{legend} .= qq( OnClick="opeNod($i,'$i');return false">);
				$gc->{legend} .= ($i+1) .'</a>';
				$gc->{legend} .= "<TD align=left>$r\n";
			}
		}
		$gc->{legend} .= '</TABLE>' unless $g_legend_full;
	}

	$Gtmp ||= $TmpPath . 'g'. time;
	my $good = $gc->{ps}->multi_out([qw(ps)]);
	$good = $gc->{img}->multi_out([qw(png ismap)]) if $good;

	return 0 unless $good;

	$gc->{map} = '';
	if(open MAP, "<$Gtmp-0.ismap") {
		my $map = '';
		while(my $line = <MAP>) { $map .= $line; }
		ismap2mymap(\$map, \$gc->{map});
		close MAP;
	} else {
		return my_error(\"Problem opening $Gtmp-0.ismap:\n$!");
	}
	my $ps = '';
	if(open PS, "<$Gtmp-0.ps") {
		while(my $line = <PS>) { $ps .= $line; }
		close PS;
	} else {
		return my_error(\"Problem opening $Gtmp-0.ps:\n$!");
	}
	$ps =~ /Pages: (\d+).*/s;
	$gc->{pages} = $1||0;

	return 1;
}

sub a2pajek {
	my $citation = shift;
	my $what = ($g_use_lcs ? 'lcs' : 'tc');
	my $hr = $hra;
	my %net = ();
	my $count = 0;
	for my $rid ($sorted_by{$what}->($hr)) {
		my $pub = $hr->{$rid};
		my $cs = get_cs($hr, $rid, $g_use_lcs);
		last unless (($g_use_val and $g_limit <= $cs) 
			or (!$g_use_val and $count < $g_limit));
		$net{$pub->{tl}} = 1;
		++$count;
	}
	my @net = sort {$a <=> $b} keys %net;
	for(my $n=0; $n<=$#net; ++$n) {
		$net{$net[$n]} = $n + 1;
	}
	my $o = ''; #"%Generated by HistCite $$VERSION\r\n";
#	$o .= '%'. (scalar localtime) ."\r\n";
#	$o .= "%$$title\r\n" if $$title;
#	$o .= '%';
#	$o .= ($g_use_lcs ? 'LCS' : 'GCS' );
#	$o .= ($g_use_val ? ' >= ' : ', top ' );
#	$o .= "$g_limit\r\n";
	$o .= "*Vertices ". @net ."\r\n";
	my $n = 0;
	for my $i (@net) {
		$o .= ++$n .' "'. ($i+1) .' ';
		if($citation) {
			$o .= brief_citation($i);
		} else {
			my $pub = $hra->{$tl[$i]};
			$o .= first_author($pub);
			$o .= ", $pub->{py}";
		}
		$o .= "\"\r\n";
	}
	$o .= "*Arcs\r\n";
	for my $i (@net) {
		for my $n (@{$hr->{$tl[$i]}->{cites}}) {
			$o .= $net{$i} .' '. $net{$n} ."\r\n" if $net{$n};
		}
	}
	return $o;
}

sub get_cs {
	my $hr = shift;
	my $ci = shift;
	my $use_lcs = shift;
	my $cs;
	if($use_lcs) {
		$cs = $hr->{$ci}->{lcs};
	} else {
		$cs = -1 == $hr->{$ci}->{tc} ? 0 : $hr->{$ci}->{tc};
	}
	return $cs;
}

sub g2html {
	my $gr = shift||\%{$gc{ur}};
	my $g = shift||'current';
	my $back = '<a class="ui" href=# OnClick="history.back();return false">Back</a>';
	my $o = '';
	add_body_script(\$o);
	$o .= $back;
	$o .= "<h3>$g{$g}->{title}</h3>\n";
	$o .= "<img src=$g.png usemap=\"#m1\" border=0>";
	$o .= "<MAP name=\"m1\">\n";
	$o .= $gr->{map};
	$o .= "</MAP><br>\n";
	$o .= qq(<span class="ui"><a href=$g.ps>PostScript</a> (Letter pages: $gr->{pages})</span>\n);
	$o .= " &nbsp; $back";
	$o .= "<p>$g{$g}->{desc}</p>\n" if $g{$g}->{desc};
	$o .= "<p>\n";
	$o .= $gr->{info};
	$o .=	"<br>\n";
	$o .= $gr->{inf2};
	$o .= $gr->{legend};
	$o .= "<p>$back";
	return $o;
}

sub g2frames {
	my $g = shift;
	my $rows = '20,*';
	$rows = '20,*,60' if $g_mk_info;
	$rows = '20,*,25%' if $g_mk_legend;
	my($gmenu, $g_file, $info_file) = -1==$g
		? ('about:blank', 'about:blank','about:blank')
		: ('gmenu', "$g.html", "info-$g.html");
	my $o = <<"";
<FRAMESET rows="$rows">
	<FRAME src="$gmenu" noresize frameborder=0 scrolling=no bordercolor=white>
	<FRAME src="$g_file" frameborder=0 name=theimage>
	<FRAME src="$info_file">
</FRAMESET>

	return $o;
}

sub g_img2frame {
	my $gr = shift||$gc;
	my $g = shift||'0';

	my $o = <<"";
<HEAD>
<STYLE type="text/css">
body {
	margin: 0;
	background: $BG_COLOR;
}
</STYLE>
</HEAD>
<BODY>
<SCRIPT>
function opeNod (a) { top.opeNod(a); }
function opeLod (d, a) { top.opeLod(d, a); } </SCRIPT>
<img src=$g.png usemap="#m1" border=0>
<MAP name="m1">
$gr->{map}</MAP></BODY>

	return $o;
}

sub g_info2frame {
	my $gr = shift||$gc;
	my $o = <<"";
<BODY VLINK=blue>
<SCRIPT>function opeNod (a) { top.opeNod(a); }
function opeLod (d, a) { top.opeLod(d, a); }
function na(){}
</SCRIPT>
<STYLE>body {
	margin: 2px 3px; padding: 0;
	font-family: Verdana; font-size: 10pt;
	background: $BG_COLOR;
}
td, th {
	font-size: 10pt;
}
.ci_title {
	font-size: 8pt; font-weight: bold;
}
.ci_il {
	color: black; text-decoration: none;	/* msie6 ! inherit */
}
.nu { text-decoration:none; }</STYLE>

	$o .= "$gr->{info}<br>\n$gr->{inf2}\n" if $gr->{info};
	$o .= $gr->{legend};
	return $o;
}

sub g_menu2frame {
	my $gr = shift||$gc;
	my $tab = '&nbsp; &nbsp;';
	my $o = <<"";
<HEAD>
<STYLE type="text/css">
body {
	margin-top: 2px; margin-bottom: 0;
	font: 14px Verdana; white-space: nowrap;
	background: $BG_COLOR;
}
</STYLE>
</HEAD>
<BODY VLINK=blue>

	$o .= qq(<a href="javascript:parent.frames[1].focus();parent.frames[1].print()" title="Print historiograph image">Print graph</a>);
	$o .= $tab;
	$o .= qq(<a href="javascript:parent.frames[2].focus();parent.frames[2].print()" title="Print info and legend for the historiograph">Print text</a>) if ($g_mk_info or $g_mk_legend);
	$o .= $tab;
	$o .= qq(<a href=# OnClick="window.open('/keepgraph','keepgraph','width=480,height=360,resizable=yes,scrollbars=yes')" title="Keep the historiograph for later review during the program run, and inclusion into HTML presentation">Keep graph</a>\n);
	$o .= $tab;
	$o .= qq(<a href="0.ps" title="Save the image in PostScript format">PostScript</a> (Letter pages: $gr->{pages})\n);
	$o .= '</BODY>';
	return $o;
}

sub ismap2mymap {
	my $sr = shift;
	my $or = shift;

	while($$sr =~ s/rectangle (.+)$//m) {
		my $line = $1;
		$line =~ s/[()]//g;
		$line =~ s/,/ /g;
		my @m = split /\s+/, $line;
		my $n = $m[4];
		my $ti = (1+$n) .' ';
		$ti .= brief_citation($n, 1);
		#coords=left,top,right,bottom
		$$or .= qq(<AREA href=# TITLE="$ti" shape=rect coords="$m[0],$m[1],$m[2],$m[3]");
		$$or .= qq( OnClick="opeNod($n,'$n');return false">\n);
	}
}

sub first_author {
	my $pub = shift;
	my($a) = split ';', $pub->{au}, 2;
	return $a;
}

sub full_authors {
	my $pub = shift;
	my $o = '';
	if($pub->{af}) {
		my @au = split '; ', $pub->{au};
		my @af = split '; ', $pub->{af};
		my $n = $#af < $#au ? $#af : $#au;
		for(my $i=0; $i<=$n; ++$i) {
			$au[$i] .= " ($af[$i])";
		}
		$o .= join '; ', @au;
	} else {
		$o .= $pub->{au};
	}
	return \$o;
}

sub limit_list {
	my $pub = shift;
	my $fi = shift;
	my $n = shift;
	my $cut = shift;
	my @a = split /; /, $pub->{$fi};
	my $etal = '';
	my $etalch = ('au' eq $fi ? '; et al.' : ' ...');
	if($cut) {
		$n = ($n > 0 ? --$n : $#a);
		$n = $#a if $n > $#a;
		$etal = ($n < $#a ? $etalch : '');
	} else {
		$n = $#a;
	}
	local $" = '; ';
	return "@a[0 .. $n]$etal";
}

sub brief_citation {
	my $tl = shift;
	my $scores = shift;
	my $ep = shift;

	my $pub = $hra->{$tl[$tl]};
	my $o = first_author($pub);
	$o .= ", $pub->{py}, ";
	if($pub->{j9}) {
		$o .= $pub->{j9};
	} else {
		$o .= substr($pub->{so}, 0, 29);
	}
	$o .= ", V$pub->{vl}" if $pub->{vl};
	$o .= ", P$pub->{bp}" if $pub->{bp};
	$o .= "-$pub->{ep}" if $ep and $pub->{bp};
	if($scores) {
		$o .= " LCS: $pub->{lcs}";
		$o .= " GCS: $pub->{tc}" if -1 < $pub->{tc};
	}
	return $o;
}

sub keep_graph_dialog {
	my $o = '';
	add_body_script(\$o, 'ui');
	$o .= "<FORM method=POST action=/keepgraph name=f>\n";
	$o .= "<INPUT type=hidden name=cmd value=keepgraph>\n";
	$o .= "Title: <INPUT type=text name=title size=42><br>\n";
	$o .= "Description:<br><TEXTAREA name=desc cols=32 rows=4></TEXTAREA><br>\n";
	$o .= "<INPUT type=submit OnClick=\"doSubmit();return false\" value='Keep This Graph'>\n";
	$o .= "</FORM>\n";
	$o .= '<SCRIPT>function doSubmit () { document.f.submit(); } </SCRIPT>';
	$o .= "<p>Please, title and describe the most recently viewed graph ";
	$o .= "(Nodes: $gc->{nodes}";
	$o .= ", Links: $gc->{edges}" if $gc->{edges};
	$o .= ").  To cancel, close this window.";
	$o .= '</BODY>';
	return $o;
}

sub keep_graph {
	my $title = shift||'Untitled';
	my $desc = shift||'';
	my $g = 1;
	for (sort {$a <=> $b} keys %g) {
		last unless exists $g{$g};
		++$g;
	}
	$g{$g}->{title} = $title;
	$g{$g}->{desc} = $desc;
	$g{$g}->{img} = $gc->{img};
	$g{$g}->{ps} = $gc->{ps};
	$g{$g}->{nodel} = $gc->{nodel};
	$g{$g}->{nodes} = $gc->{nodes};
	$g{$g}->{edges} = $gc->{edges};
	$g{$g}->{map} = $gc->{map};
	$g{$g}->{info} = $gc->{info};
	$g{$g}->{inf2} = $gc->{inf2};
	$g{$g}->{legend} = $gc->{legend};
	$g{$g}->{pages} = $gc->{pages};
	for my $e qw(png ps) {
		my_cp("$Gtmp-0.$e", "$Gtmp-$g.$e");
	}
	for my $n (eval $g{$g}->{nodel}) {
		++$on_kept_graph{$n};
	}
}

sub head_section {
	my($head, $ent, $subhead, $items, $what) = @_;
	$subhead ||= '';
	$what ||= '';
	my $prefix = $main{$ent} ? '' : '../';
	my $v = $view{main}{$VIEW};
	my $o = <<"";
<SCRIPT>
function glossary () { window.open(root+'glossary.html','gloss','width=640,height=570,resizable=yes,scrollbars=yes') }
function opeNod (a) { window.open(root+'node/'+a+'.html',a,'width=770,height=570,resizable=yes,scrollbars=yes') }
function opeLod (dp, a) { if(''==dp) d='$ent'; else d=dp; var w = d; w = w.replace(/[-\\/]/g, '');
	window.open(root+d+'/'+a+'.html',w+a,'width=640,height=546,resizable=yes,scrollbars=yes') }
function na(){}
</SCRIPT>

	$o .= '<br id="menu_pm">' if $LIVE;	##DOUBLE CHECK THIS FOR PRINT

	my $title = $$title_line||'Untitled Collection';
	my $desc = $$caption||($LIVE ? 'Click to change title and description':'');
	my $clk_prop = $LIVE ? qq(OnClick="window.open('/properties','settings','width=490,height=480,resizable=yes,scrollbars=no,status=yes');return false;") : '';

	my $head_top = ($LIVE && !$IE6) ? 'fixed;top:21px;padding-right:3px;' :'';
	my $pos = ($LIVE && !$IE6) ? 'fixed' : 'absolute';
	my $stats2_pad = ($main{$ent} && 'main' ne $ent or ($v->{lcsb} or $v->{lcse} or $v->{eb} or $CUST))
		? '4px 4px 5px 8px' : '0';
	$o .= <<"";
<STYLE>
#head {
	position: ${head_top}left:0; padding-left:4px; background:#fff;
	z-index:2; margin:0 0 8px 0; border-bottom:solid #000 1px;
}
#title {
	padding-bottom: 4px; font-size: 1.3em; font-weight: bold;
	max-width: 600px; /* non default overflow gives odd z-effects in FF */
}
#desc {
	position: $pos; left: 4px; top: ${\($LIVE ? '3.1':'1.8')}em;
	padding: 2px 8px 4px 8px; white-space: normal; max-width: 480px;
	background: #ffffcc; font-weight: normal; font-size: 10pt;
	border: solid #000 1px;
	display: none; z-index: 11;
}
#atitle { cursor: ${\($LIVE ? 'pointer' : 'text')};}
#atitle, #stats {
	text-decoration: none; color: #000;
}
#stats2 {
	position: $pos; right: 0px; padding: $stats2_pad;
	background: white;
	display: none; z-index: 11;
}
#atitle:hover #desc, #stats:hover #stats2 {
	display: block;
}
\@media print {
	#head { position: static; }
	#menu_pm { line-height: 0; }
	#back { display: none; }
}
</STYLE>
<!-- FF 3 only? fix -->
<div id=head style="width:99%">
<TABLE width=100% cellpadding=0 cellspacing=0 style="margin:0 0 3px 0">
<TR valign=top><TD align=left width=60%>
<div id=title><a id=atitle $clk_prop>$title${\($desc ? "<div id=desc>$desc</div>":'')}</a></div>

	$o .= '<TD align=center>';
	unless($LIVE) {
		$o .= qq(<a href=# OnClick="window.open('${prefix}graph/list.html','graph',$win_opts)" class=nonprn>Historiographs</a>);
	}
	$o .= '<TD nowrap align=right rowspan=2 width=5%>';
	unless($LIVE) {
		$o .= '<div class=nonprn>';
		if('co' eq $ent or 'wd' eq $ent) {
			$o .= window_help("../help/$ent.html");
		}
		$o .= "<a href=javascript:glossary()>Glossary</a>&nbsp;&nbsp;<a href=\"http://www.histcite.com/HTMLHelp/guide.html\" target=guide>HistCite Guide</a>";
		$o .= "&nbsp;&nbsp;<a href=# OnClick=\"about(); return false\">About</a>";
		$o .= '</div>';
	}

	my $stats_back = '';
	if($NODES) {
		$what = 'gcs' if 'tc' eq $what;
		$o .= "<a id=stats>\n";
		my $grands = '';
		get_grand_tots($ent, $what, \$grands);
		$grands .= '<br>';
		if($main{$ent} && 'main' ne $ent) {
			my $lists = '';
			get_list_tots($what, $items, \$lists, $ent);
			$o .= $lists;
			$stats_back = $lists;
			$grands .= "$list_span<br>" if $list_span;
		} else {
			$o .= $grands;
			$stats_back = $grands;
			$grands = '';
		}
		if($uaIE7 && $LIVE && ($main{$ent} or 'au' eq $ent)) {
			$o .= '<br>';
			$stats_back .= '<br>';
		}

		if('base' ne $VIEW and ($main{$ent} or 'au' eq $ent)
			or 'temp' eq $ent or 'mark' eq $ent) {
			$o .= '<div id=stats2>';
			if($main{$ent} && 'main' ne $ent) {
				$o .= $grands;
			} elsif($v->{lcsb} or $v->{lcse} or $v->{eb} or $CUST) {
				$o .= " Number of records ${\($bcut_years+$ecut_years)} years old and older: $net_mature ("
					. sprintf("%.1f", $net_mature/$NODES*100) .'%)';
			}
			$o .= '</div>';
		}
		$o .= '</a>';
	}
	$o .= "<TR><TD colspan=2 width=95%>$head $subhead";
	$o .= '</TABLE>';
	$o .= '</div>';

	$o .= <<"" if $LIVE && !$IE6;
<div id=back style="visibility:hidden;margin-bottom:8px;">
<TABLE width=100% cellpadding=0 cellspacing=0 style="margin:0 0 3px 0;">
<TR valign=top><TD align=left width=60%>
<div id=title><a>$title</a></div>
<TD align=center>
<TD nowrap align=right rowspan=2 width=5%>
<a id=stats>$stats_back
</div>
<TR><TD colspan=2 width=95%>$head $subhead</TABLE></div>

	if($LIVE) {
		add_toggle_script(\$o) if $m_form_on or ('mark' eq $ent and $MARKS);
	} else {
		my $ltime = strftime "%d %B %Y", localtime;
		$ltime =~ s/^0//;
		$o .= "<div align=right>$ltime</div>\n";
	}
	return $o;
}

sub get_grand_tots {
	my($ent, $what, $sr) = @_;
	my $v = $view{main}{$VIEW};
	my @g = ();
	for my $f qw(lcs lcsx gcs scs ncr na) {
		next unless ($v->{$f} or $CUST);
		if('gcs' eq $f and !$net_tgcs_num) {
			push @g, 'GCS n/a';
		} elsif('scs' eq $f and !$net_tscs_num) {
			push @g, 'OCS n/a';
		} else {
			push @g, "$f{$f} ". eval("\$net_t$f");
		}
	}
	local $" = ', ';
	$$sr = "Grand Totals: @g" if @g;
	@g = ();
	if($main{$ent} && 'base' ne $VIEW) {
		for my $f qw(lcs lcsx gcs scs ncr na) {
			next unless ($v->{$f} or $CUST);
			if('gcs' eq $f && $net_tgcs_num < $NODES) {
				if($net_tgcs_num) {
					push @g, 'GCS '. nbsp($net_tgcs / $net_tgcs_num, 2). " ($net_tgcs_num recs)";
				} else {
					push @g, 'GCS n/a';
				}
			} elsif('scs' eq $f && $net_tscs_num < $NODES) {
				if($net_tscs_num) {
					push @g, 'OCS '. nbsp($net_tscs / $net_tscs_num, 2). " ($net_tscs_num recs)";
				} else {
					push @g, 'OCS n/a';
				}
			} else {
				push @g, "$f{$f} ". eval("nbsp(\$net_t$f / $NODES, 2)");
			}
		}
		$$sr .= "<br>Means: @g" if @g;
		if('main' eq $ent && 'base' ne $VIEW && $stats_quarts{$what}) {
			$$sr .= "<br>$f{$what} Quartiles<span id=erecs></span>: ";
			$$sr .= "Q1 <span id=q1>...</span>, ";
			$$sr .= "Me <span id=median>...</span>, ";
			$$sr .= "Q3 <span id=q3>...</span>";
		}
	}
	$$sr .= '<br>';
	$$sr .= "Collection span: $net_first_year - $net_last_year";
	if('base' ne $VIEW) {
		$$sr .= " (". ($net_last_year - $net_first_year + 1) ." years)";
	}
}

sub get_list_tots {
	my($what, $items, $sr, $ent) = @_;
	my $v = $view{main}{$VIEW};
	my @l_f = qw(lcs lcsx gcs scs ncr na);
	my @l = ();
	for my $f (@l_f) {
		next unless ($v->{$f} or $CUST);
		if('gcs' eq $f and !$list_gcs_num) {
			push @l, 'GCS n/a';
		} elsif('scs' eq $f and !$list_scs_num) {
			push @l, 'OCS n/a';
		} else {
			push @l, "$f{$f} ". eval("\$list_$f");
		}
	}
	local $" = ', ';
	$$sr = "List Totals: @l<br>" if @l;
	@l = ();
	if('base' ne $VIEW and $items) {
		for my $f (@l_f) {
			next unless ($v->{$f} or $CUST);
			if('gcs' eq $f or 'scs' eq $f) {
				my $CS = uc $f;
				if(eval("\$list_${f}_num")) {
					push @l, "$CS ". eval("sprintf('%.2f', \$list_$f/\$list_${f}_num)") .' ('. eval("\$list_${f}_num") .' recs)';
				} else {
					push @l, "$CS n/a";
				}
			} else {
				push @l, "$f{$f} ".  eval("sprintf('%.2f', \$list_$f/$items)");
			}
		}
		$$sr .= "List Means: @l<br>" if @l;
		if($stats_quarts{$what}) {
			$$sr .= "List $f{$what} Quartiles<span id=erecs></span>: ";
			$$sr .= "Q1 <span id=q1>...</span>, ";
			$$sr .= "Me <span id=median>...</span>, ";
			$$sr .= "Q3 <span id=q3>...</span><br>";
		}
	}
	return if 'base' eq $VIEW;

	$$sr .= "$list_hindex<br>" if $list_hindex;
}

sub new_table_menu {
	my $what = shift||'';
	my $pubs = $LIVE ? '' : '-pubs';
	my %name = (qw(tl Records mark Marks au Authors so Journals or),
		'Cited References', qw(wd Words tg Tags));
	my %count = (tl => 0+@tl, mark => $MARKS, au => 0+@aui, so => 0+@jni,
		or => 0+@ori, wd => 0+@wdi, tg => 0+@tgi );
	my $list = '';
	$list = 'list/' if 'tl' eq $what;
	$list = '../list/' if 'mark' eq $what or 'temp' eq $what;
	my %url = qw(mark /mark/index.html);
##	$url{tl} = '../index.html'; ##-tl fix after new html intro page!!!!
	$url{tl} = $LIVE ? '/' : '../index-tl.html';
	my @fi = ();
	for my $fi qw(tl au so) {
		next if 'mark' eq $fi and !$LIVE;
		push @fi, $fi;
	}
	push @fi, 'or' if $DO_OR;
	push @fi, 'wd' if $DO_WD;
	push @fi, 'tg' if $TAGS > 1 or ($TAGS == 1 && not defined $tg{Other});
	push @fi, 'mark' if $MARKS;

	my $border_top = ($ie && !$uaIE8 && $LIVE) ? "border-top:solid $MENU_COLOR 3px;" : '';
	my $o = qq(<div class="index" style="$border_top">);
	$o .= '<span class="x"><a href="?showai=OFF" title="Hide Analyses index">X</a></span>' if $LIVE;

	for my $fi (@fi) {
		if($what eq $fi) {
	##		$o .= '<b>';
		} else {
			my $url = $url{$fi}; $url ||= "$list$fi$pubs.html";
			$o .= "<a href=$url>" 
		}
		$o .= $name{$fi};
		if($what eq $fi) {
	##		$o .= '</b>';
		} else {
			$o .= '</a>';
		}
		$o .= ": $count{$fi}";
		$o .= ', ' unless $fi eq $fi[$#fi];
	}

	$o .= <<"" if $DIRTY;
 &nbsp; <a href=# onclick="location.replace('update_modules?url='+location.pathname+'&${\(time)}');return false" title="Update analysis lists to reflect changes"><font color=red>Update lists</font></a>

	$o .= "\n";
	$o .= "<br><span class=nonprn>";

	for my $fi qw(py dt la in i2 co) {
		next if 'py' eq $fi and 0 > $#tl;
		if($what eq $fi) {
	##		$o .= '<b>';
		} else {
#			if($what) {
				my $url = $url{$fi}; $url ||= "$list$fi$pubs.html";
				my $recs = @{$ari{$fi}};
				$o .= "<a href=$url title=' $items{$fi}: $recs '>" 
#				$o .= "<a href=/list/$fi$pubs.html style=text-decoration:none;>" 
#			} else {
#				$o .= "<a href=# OnClick=\"window.open('list/$fi$pubs.html','list',$win_opts)\">";
#			}
		}
		$o .= 'py' eq $fi ? 'Yearly output' : $f_ful{$fi};
		if($what eq $fi) {
	##		$o .= '</b>';
		} else {
			$o .= '</a>';
		}
		$o .= "\n|&nbsp;" unless 'co' eq $fi;
	}
	$o .= '</span></div>';
	return $o;
}

sub graph_list {
	my $path = ($LIVE ? '/graph/' : '');
	my $o = "<TITLE>HistCite - $$title</TITLE>\n";
	add_body_script(\$o);
	$o .= '<div class="ui" style="margin:2px 0 8px;">Historiographs &nbsp; ';
	$o .= "<a href=/graph/GraphMaker>Graph Maker</a> &nbsp;\n" if $LIVE;
	add_close_link(\$o);
	$o .= '</div>';
	$o .= "<DIV style='margin:2px;font-size:1.1em;'><b>$$title_line</b></DIV>";

	my @g = (sort {$g{$a}->{title} cmp $g{$b}->{title}} keys %g);
	return $o if 0 > $#g;

	$o .= '<FORM>' if $LIVE;
	$o .= qq(<TABLE border=0 cellpadding=5 cellspacing=2 style="border: 2px solid $TABLE_BORDER_COLOR;">\n);
	$o .= "<TR bgcolor=$TH_COLOR align=center><TD align=right>#<TD width=20%>Title<TD>Records<TD>Links<TD>Information<TD>Description</TR>\n";
	for(my $i=0; $i<=$#g; ++$i) {
		$o .= '<TR valign=top align=right';
		$o .= ' class='. ($i % 2 ? 'evn' : 'odd');
		$o .= '><TD>'. (1 + $i);
		$o .= "<TD align=left>";
		$o .= "<INPUT type=checkbox name=graph value=$g[$i]>&nbsp;" if $LIVE;
		$o .= "<a href=${path}$g[$i].html>$g{$g[$i]}->{title}</a>";
		$o .= "</TD><TD>". ($g{$g[$i]}->{nodes}||0);
		$o .= "</TD><TD>". ($g{$g[$i]}->{edges}||'&nbsp;');
		$o .= "</TD><TD align=left>". ($g{$g[$i]}->{inf2}||'&nbsp;');
		$o .= "</TD><TD align=left>". ($g{$g[$i]}->{desc}||'&nbsp;');
		$o .= "\n";
	}
	$o .= "</TABLE>\n<br>";
	$o .= '<INPUT class="ui" type=submit value=Delete></FORM>' if $LIVE;
	$o .= '</BODY>';
	return $o;
}

sub my_cp {
	my($src, $dst) = @_;
	if(open SRC, "<$src") {
		binmode SRC;
		if(open DST, ">$dst") {
			binmode DST;
			my $buff;
			while(read(SRC, $buff, 8 * 1024)) {
				print DST $buff;
			}
			close DST;
		} else {
			return my_error(\"Cannot create file '$dst': $!");
		}
		close SRC;
	} else {
		return my_error(\"Cannot open file '$src': $!");
	}
	return 1;
}

sub my_error {
	my($sr, $title, $nolog) = @_;
	print LOG "<font color=red>$$sr</font>\n" unless $nolog;
	if('MSWin32' eq $^O) {
		if($title) {
			Win32::MsgBox("$$sr", MB_ICONEXCLAMATION, $title)
		} else {
			Win32::MsgBox("$$sr", MB_ICONSTOP, 'HistCite Error')
		}
	} else {
		print "$$sr\n\n";
	}
	return 0;
}

END {
	if($PortFile) {
		unlink $PortFile;
		if($Gtmp) {
			for my $f qw(png ismap ps dot) {
				unlink "$Gtmp-0.$f";
			}
			for my $g (keys %g) {
				for my $f qw(png ps) {
					unlink "$Gtmp-$g.$f";
				}
			}
		}
	}
}