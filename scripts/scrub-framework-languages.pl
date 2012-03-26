#!/usr/bin/perl
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Removes all the Sparkle languages that aren't also part of the app bundle, since those
# languages can't be loaded anyway.
use warnings;
use strict;

# Map of language names to cannonical forms for comparison.
my %language_code = ( "English" => "en" );

my $app_resources = "$ENV{BUILT_PRODUCTS_DIR}/$ENV{PRODUCT_NAME}.app/Contents/Resources";
my $sparkle_resources = "$ENV{BUILT_PRODUCTS_DIR}/$ENV{PRODUCT_NAME}.app/Contents/Frameworks/Sparkle.framework/Resources";
my $breakpad_resources = "$ENV{BUILT_PRODUCTS_DIR}/$ENV{PRODUCT_NAME}.app/Contents/Frameworks/Breakpad.framework/Resources/crash_report_sender.app/Contents/Resources";
die "Can't find $ENV{PRODUCT_NAME} resource directory" unless -d $app_resources;

my %standardized_app_languages;
for (&languages_for_bundle($app_resources)) {
  $standardized_app_languages{&standardized_language($_)} = 1;
}

&scrub_framework("Sparkle", $sparkle_resources);
&scrub_framework("Breakpad", $breakpad_resources);

sub scrub_framework {
  my ($framework_name, $resources_path) = @_;
  my @framework_languages = &languages_for_bundle($resources_path);
  die "Can't find $framework_name resource directory" unless -d $resources_path;

  print "Scrubbing $framework_name lprojs...\n";
  foreach my $language (@framework_languages) {
    unless ($standardized_app_languages{&standardized_language($language)}) {
      my $lproj = "$resources_path/$language.lproj";
      print "  Removing unnecessary $framework_name lproj: $lproj\n";
      system("/bin/rm", "-rf", $lproj);
    }
  }
}

sub languages_for_bundle {
  my ($resources_dir) = @_;
  opendir(RESDIR, $resources_dir) or die "Can't open resource directory '$resources_dir";
  my @languages = map { $_ =~ s/.lproj//; $_ } grep { /\.lproj/ } readdir(RESDIR);
  closedir(RESDIR);
  return @languages;
}

sub standardized_language {
  my ($language) = @_;
  return $language_code{$language} || $language;
}
