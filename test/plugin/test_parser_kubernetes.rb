require 'helper'
require 'fluent/plugin/parser_kubernetes'

class KubernetesParserTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  CONFIG = %(
    keep_time_key false
    time_format %Y-%m-%dT%H:%M:%S.%N%:z
  )

  def create_driver(conf)
    Fluent::Test::Driver::Parser.new(Fluent::Plugin::KubernetesParser).configure(conf)
  end

  sub_test_case 'should parse logs' do
    test 'kubelet without quoting' do
      d = create_driver("#{CONFIG}\nforce_year 2022\ndefault_tz +02:00")
      text = 'I0524 16:21:12.823864    1025 log.go:195] http: superfluous response.WriteHeader call from k8s.io/kubernetes/vendor/github.com/emicklei/go-restful.(*Response).WriteHeader (response.go:220)'

      d.instance.parse(text) do |time, record|
        assert_equal_event_time(event_time('2022-05-24T16:21:12.823864+02'), time)
        assert_equal({
                       'level' => 'info',
                       'file' => 'log.go',
                       'line' => 195,
                       'msg' => 'http: superfluous response.WriteHeader call from k8s.io/kubernetes/vendor/github.com/emicklei/go-restful.(*Response).WriteHeader (response.go:220)',
                       'threadid' => 1025
                     }, record)
      end
    end
    test 'kubelet without quoting, warn' do
      d = create_driver("#{CONFIG}\nforce_year 2022\ndefault_tz +02:00")
      text = 'W0627 12:09:57.042726  462622 empty_dir.go:519] Warning: Failed to clear quota on /var/lib/kubelet/pods/5d43adc3-c033-4475-b15c-34610db9c706/volumes/kubernetes.io~configmap/fluentd-config: clearQuota called, but quotas disabled'

      d.instance.parse(text) do |time, record|
        assert_equal_event_time(event_time('2022-06-27T12:09:57.042726+02'), time)
        assert_equal({
                       'level' => 'warn',
                       'file' => 'empty_dir.go',
                       'line' => 519,
                       'msg' => 'Warning: Failed to clear quota on /var/lib/kubelet/pods/5d43adc3-c033-4475-b15c-34610db9c706/volumes/kubernetes.io~configmap/fluentd-config: clearQuota called, but quotas disabled',
                       'threadid' => 462_622
                     }, record)
      end
    end

    test 'kubelet quoted msg' do
      d = create_driver("#{CONFIG}\nforce_year 2022\ndefault_tz +02:00")
      text = 'I0524 17:05:44.446677    1025 topology_manager.go:200] "Topology Admit Handler"'

      d.instance.parse(text) do |time, record|
        assert_equal_event_time(event_time('2022-05-24T17:05:44.446677+02'), time)
        assert_equal({
                       'level' => 'info',
                       'file' => 'topology_manager.go',
                       'line' => 200,
                       'msg' => 'Topology Admit Handler',
                       'threadid' => 1025
                     }, record)
      end
    end

    test 'kubelet with some context' do
      d = create_driver("#{CONFIG}\nforce_year 2022\ndefault_tz +02:00")
      text = 'I0524 17:11:56.952306    1025 kubelet_volumes.go:160] "Cleaned up orphaned pod volumes dir" podUID=c50c3c96-b448-46a8-aff0-ef61795696f7 path="/var/lib/kubelet/pods/c50c3c96-b448-46a8-aff0-ef61795696f7/volumes"'

      d.instance.parse(text) do |time, record|
        assert_equal_event_time(event_time('2022-05-24T17:11:56.952306+02'), time)
        assert_equal({
                       'level' => 'info',
                       'file' => 'kubelet_volumes.go',
                       'line' => 160,
                       'msg' => 'Cleaned up orphaned pod volumes dir',
                       'threadid' => 1025,
                       'path' => '/var/lib/kubelet/pods/c50c3c96-b448-46a8-aff0-ef61795696f7/volumes',
                       'podUID' => 'c50c3c96-b448-46a8-aff0-ef61795696f7'
                     }, record)
      end
    end

    test 'kubelet with some array in context' do
      d = create_driver("#{CONFIG}\nforce_year 2022\ndefault_tz +02:00")
      text = 'I0527 09:00:05.110852    1025 eviction_manager.go:167] "Failed to admit pod to node" pod="monitoring/prometheus-k8s-0" nodeCondition=[DiskPressure]'

      d.instance.parse(text) do |time, record|
        assert_equal_event_time(event_time('2022-05-27T09:00:05.110852+02'), time)
        assert_equal({
                       'level' => 'info',
                       'file' => 'eviction_manager.go',
                       'line' => 167,
                       'msg' => 'Failed to admit pod to node',
                       'nodeCondition' => ['DiskPressure'],
                       'pod' => 'monitoring/prometheus-k8s-0',
                       'threadid' => 1025
                     }, record)
      end
    end

    test 'containerd kv logs' do
      d = create_driver(CONFIG)
      text = 'time="2022-05-24T14:08:25.144534370+02:00" level=info msg="loading plugin \"io.containerd.grpc.v1.healthcheck\"..." type=io.containerd.grpc.v1'

      d.instance.parse(text) do |time, record|
        puts "time: #{time}, record: #{record}"
        assert_equal_event_time(event_time('2022-05-24T14:08:25.144534370+02:00'), time)
        assert_equal({
                       'level' => 'info',
                       'msg' => 'loading plugin "io.containerd.grpc.v1.healthcheck"...',
                       'type' => 'io.containerd.grpc.v1'
                     }, record)
      end
    end
  end
end
