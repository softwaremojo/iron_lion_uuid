# frozen_string_literal: true

namespace :iron_lion do
  desc "Install IronLion's Postgres functions and id triggers (runs after every migration)"
  task install: :environment do
    Rails.application.eager_load!
    report = ActiveRecord::Base.connection_pool.with_connection { IronLion::Installer.new(_1).call }
    if report.installed.empty? && report.skipped.empty?
      puts "IronLion: installed; no tables use IronLion ids yet"
    else
      puts "IronLion:\n#{report}"
    end
  end

  desc "Remove IronLion's Postgres functions and id triggers"
  task uninstall: :environment do
    ActiveRecord::Base.connection_pool.with_connection { IronLion::Installer.new(_1).uninstall }
  end
end
