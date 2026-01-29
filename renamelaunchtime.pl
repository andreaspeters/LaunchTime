#!/usr/bin/perl
use strict;
use warnings;
use File::Find;
use File::Basename;
use Cwd 'abs_path';

# ------------------ CONFIG / ARGS ------------------

my $gitbranch = "playstore_rename";
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

print "Base dir : $basedir\n";
print "Branch   : $gitbranch\n";
print "Rename   : $from_pack  ->  $to_pack\n\n";

# ------------------ SAFETY CHECK ------------------

my @status = `git status -s`;
die "❌ Git working tree not clean:\n@status\n" if @status;

# ------------------ GIT BRANCH ------------------

system("git checkout -b $gitbranch") == 0
    or die "❌ Failed to create/switch branch $gitbranch\n";

print "✅ Switched to new branch $gitbranch\n";

# ------------------ PATH CONVERSION ------------------

(my $from_dir = $from_pack) =~ s/\./\//g;
(my $to_dir   = $to_pack)   =~ s/\./\//g;

# Typical Android source roots
my @java_roots = (
    "app/src/main/java",
    "app/src/main/kotlin"
);

for my $root (@java_roots) {
    next unless -d $root;

    my $old_path = "$root/$from_dir";
    my $new_path = "$root/$to_dir";

    next unless -d $old_path;

    print "📁 Moving package directory:\n   $old_path\n   -> $new_path\n";
    system("git mv \"$old_path\" \"$new_path\"") == 0
        or die "❌ git mv failed\n";
}

# ------------------ FILE CONTENT REPLACEMENT ------------------

my %skip_dirs = map { $_ => 1 } qw(
    .git .gradle .idea build captures out
);

sub wanted {
    my $file = $File::Find::name;
    my $base = basename($file);

    # Skip dirs
    if (-d $file) {
        if ($skip_dirs{$base}) {
            $File::Find::prune = 1;
        }
        return;
    }

    return unless -T $file;  # text files only

    open my $in,  '<:utf8', $file or return;
    my @lines = <$in>;
    close $in;

    my $changed = 0;
    for (@lines) {
        $changed ||= s/\b\Q$from_pack\E\b/$to_pack/g;
    }

    if ($changed) {
        print "✏️  Updated: $file\n";
        open my $out, '>:utf8', $file or die "Cannot write $file: $!";
        print $out @lines;
        close $out;
    }
}

print "\n🔍 Replacing package name in files...\n";
find(\&wanted, $basedir);

print "\n🎉 Done! Package renamed successfully.\n";
print "👉 Next steps:\n";
print "   • Invalidate caches / restart IDE\n";
print "   • Clean & rebuild project\n";
print "   • Check AndroidManifest.xml applicationId\n";

