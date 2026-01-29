#!/usr/bin/perl
use strict;
use warnings;
use File::Find;
use File::Path qw(make_path);
use File::Copy qw(move);
use File::Basename;
use Cwd 'abs_path';

# ------------------ ARGUMENTE ------------------

my $gitbranch = "playstore91";
my $from_pack = "com.quaap.launchtime";
my $to_pack   = "biz.aventer.launchtime";
my $basedir   = ".";

if (@ARGV) {
    die "Usage: $0 [gitbranch from_package to_package [basedir]]\n"
        unless @ARGV == 3 || @ARGV == 4;

    ($gitbranch, $from_pack, $to_pack, $basedir) = @ARGV;
}

$basedir = abs_path($basedir);
chdir $basedir or die "Cannot chdir to $basedir: $!";

print "\n=== Android Package Rename Tool ===\n";
print "Base dir : $basedir\n";
print "Branch   : $gitbranch\n";
print "Rename   : $from_pack  ->  $to_pack\n\n";

# ------------------ GIT CHECK ------------------

my @status = `git status -s`;
die "❌ Git working tree not clean:\n@status\n" if @status;

system('git', 'checkout', '-b', $gitbranch) == 0
    or die "❌ Failed to create branch $gitbranch\n";

print "✅ Switched to new branch\n";

# ------------------ PACKAGE PFAD ------------------

(my $from_dir = $from_pack) =~ s/\./\//g;
(my $to_dir   = $to_pack)   =~ s/\./\//g;

my @source_roots = (
    "app/src/main/java",
    "app/src/main/kotlin"
);

for my $root (@source_roots) {
    next unless -d $root;

    my $old = "$root/$from_dir";
    my $new = "$root/$to_dir";

    unless (-d $old) {
        print "ℹ️  No directory $old — skipping folder move\n";
        next;
    }

    if ($old eq $new) {
        print "ℹ️  Source and destination identical — skipping move\n";
        next;
    }

    print "📁 Moving directory:\n  $old\n  -> $new\n";

    (my $parent = $new) =~ s{/[^/]+$}{};
    make_path($parent) unless -d $parent;

    move($old, $new) or die "❌ Move failed: $!\n";
}

# ------------------ TEXT ERSETZUNG (ENCODING-SICHER) ------------------

my %skip_dirs = map { $_ => 1 } qw(
    .git .gradle .idea build captures out
);

sub wanted {
    my $path = $File::Find::name;
    my $base = basename($path);

    if (-d $path) {
        if ($skip_dirs{$base}) {
            $File::Find::prune = 1;
        }
        return;
    }

    return unless -T $path;
    return if -s $path > 5_000_000;   # sehr große Dateien überspringen

    open my $in, '<:raw', $path or return;
    local $/;
    my $content = <$in>;
    close $in;

    my $changed = ($content =~ s/(?<![A-Za-z0-9_])\Q$from_pack\E(?![A-Za-z0-9_])/$to_pack/g);

    if ($changed) {
        print "✏️  Updated: $path\n";
        open my $out, '>:raw', $path or die "Cannot write $path: $!";
        print $out $content;
        close $out;
    }
}

print "\n🔍 Replacing package name inside files...\n";
find(\&wanted, $basedir);

print "\n🎉 DONE!\n";
print "Next steps in Android Studio:\n";
print " • Sync Gradle\n";
print " • Clean Project\n";
print " • Rebuild\n\n";
print "Also verify in build.gradle:\n";
print " • applicationId\n";
print " • namespace (AGP 8+)\n";

