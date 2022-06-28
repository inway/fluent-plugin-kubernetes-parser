#
# Copyright 2022- Sebastian Podjasek
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fluent/log'
require 'fluent/plugin/parser'

module Fluent
  module Plugin
    class KubernetesParser < Fluent::Plugin::Parser
      Fluent::Plugin.register_parser('kubernetes', self)

      config_param :delimiter, :string, default: ' '
      config_param :default_tz, :string, default: '+00:00'
      config_param :force_year, :string, default: nil
      config_param :keep_time_key, :bool, default: false
      config_param :time_format, :string, default: nil
      config_param :time_key, :string, default: 'time'

      def configure(conf)
        super

        raise ConfigError, "delimiter must be a single character. #{@delimiter} is not." if @delimiter.length != 1

        # Kubernetes logging format
        # https://kubernetes.io/docs/concepts/cluster-administration/system-logs/
        # https://github.com/kubernetes/community/blob/master/contributors/devel/sig-instrumentation/logging.md
        #
        # <klog header> "<message>" <key1>="<value1>" <key2>="<value2>" ...
        # Lmmdd hh:mm:ss.uuuuuu threadid file:line] msg...
        #
        # where the fields are defined as follows:
        #   L                A single character, representing the log level (eg 'I' for INFO)
        #   mm               The month (zero padded; ie May is '05')
        #   dd               The day (zero padded)
        #   hh:mm:ss.uuuuuu  Time in hours, minutes and fractional seconds
        #   threadid         The space-padded thread ID as returned by GetTID()
        #   file             The file name
        #   line             The line number
        #   msg              The user-supplied message
        @klog_regexp = /
          ^
          (?<log_level>[A-Z])(?<month>\d{2})(?<day>\d{2})\s+
          (?<time>\d{2}:\d{2}:\d{2}(|\.\d+))\s+
          (?<threadid>\d+)\s+
          (?<file>[^ ]*):(?<line>\d+)\]\s
          (
            "(?<msg>([^"\\]*(?:\\.[^"\\]*)*))"(|\s+(?<kv>.*))
            |
            (?<greedy_msg>.*)
          )
          $
        /x

        # KV format used by containerd
        @kv_regexp = /
          (?<key>[^\s=]+)
          (
            \s
            |
            =
            (?<value>
              "(?<quoted>([^"\\]*(?:\\.[^"\\]*)*))"
              |
              \[(?<array>([^\]\\]*(?:\\.[^\]\\]*)*))\]
              |
              [^\s]*
            )
          )
        /x
      end

      def parse(text)
        if text.nil? || text.empty?
          yield nil, nil
          return
        end

        time = nil
        record = {}

        matches_klog = @klog_regexp.match(text)

        unless matches_klog.nil?
          captures = matches_klog.named_captures

          captures['msg'] = captures['greedy_msg'] unless captures['greedy_msg'].nil?
          captures.delete('greedy_msg')

          unless captures['time'].nil?
            record['time'] =
              format('%s-%s-%sT%s%s', @force_year.nil? ? Time.now.year : @force_year, captures['month'], captures['day'],
                     captures['time'], @default_tz)
            captures.delete('month')
            captures.delete('day')
            captures.delete('time')
          end

          text = captures['kv']
          captures.delete('kv')

          captures.each do |key, value|
            if key == 'log_level'
              # As seen here:
              # https://github.com/kubernetes/klog/blob/9ad246211af1ed84621ee94a26fcce0038b69cd1/klog.go#L112
              record['level'] = case value
                                when 'I'
                                  'info'
                                when 'W'
                                  'warn'
                                when 'E'
                                  'error'
                                when 'F'
                                  'fatal'
                                else
                                  value
                                end
            elsif %w[threadid line].include?(key)
              record[key] = value.to_i
            else
              record[key] = value
            end
          end
        end

        unless text.nil?
          text.scan(@kv_regexp).each do |key, value, quoted, array|
            record[key] = if !quoted.nil?
                            quoted.gsub(/\\(.)/, '\1')
                          elsif !array.nil?
                            array.split(',').map(&:strip)
                          else
                            value
                          end
          end
        end

        time = parse_time(record)

        yield time, record
      end
    end
  end
end
