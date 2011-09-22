require 'tmpdir'
require 'json'
require 'sinatra/base'
module Stamina
  module Gui
    class App < Sinatra::Base

      ### business

      def go_for(tempdir, src)
        source = File.join(tempdir, "source.rb")
        File.open(source, "w"){|io| io << src}
        Stamina::Command::Run.run(["--all", "--gif", source])
      end

      ### file helpers

      def self._(path)
        File.expand_path(path, File.dirname(__FILE__))
      end
      def _(path); self.class._(path); end

      # main config, statics and root
      enable :sessions

      set :public, _('public')
      set :views,  _('templates')

      get '/' do
        erb :index, :locals => {
          :source_code => 'hello = regular "(hello world)*"',
          :variables   => [:hello]
        }
      end

      # THE go post service

      post '/go' do
        session[:tmpdir] ||= Dir.mktmpdir("stamina-gui")
        context = go_for(session[:tmpdir], params[:src])
        content_type :json
        context.collect{|k,v|
          v.respond_to?(:to_dot) ? k : nil
        }.compact.to_json
      end

      # image results

      get '/image/:name' do
        cache_control :no_cache
        expires 0, :no_cache
        erb :image, :locals => { :name => params[:name] }
      end

      get '/automata/*' do
        cache_control :no_cache
        expires 0, :no_cache
        session[:tmpdir] ||= Dir.mktmpdir("stamina-gui")
        send_file File.join(session[:tmpdir], params[:splat])
      end

    end # class App
  end # module Gui
end # module Stamina
