require 'rails_helper'
require 'test_track_rails_client/rspec_helpers'

RSpec.describe TestTrack do
  describe ".update_config" do
    it "yields an updater" do
      block_execution_count = 0
      TestTrack.update_config do |c|
        expect(c).to be_a(TestTrack::ConfigUpdater)
        block_execution_count += 1
      end
      expect(block_execution_count).to eq 1
    end
  end

  describe ".enabled?" do
    around do |example|
      original_enabled = TestTrack.instance_variable_get("@enabled")
      example.run
      TestTrack.enabled_override = original_enabled
    end

    context "test environment" do
      it "is not enabled by default" do
        expect(TestTrack).not_to be_enabled
      end

      it "can be enabled" do
        TestTrack.enabled_override = true
        expect(TestTrack).to be_enabled
      end
    end

    context "non-test environment" do
      around do |example|
        with_rails_env("development") { example.run }
      end

      it "is enabled by default" do
        expect(TestTrack).to be_enabled
      end

      it "can be disabled" do
        TestTrack.enabled_override = false
        expect(TestTrack).not_to be_enabled
      end
    end
  end

  describe "analytics" do
    it "wraps default client in SafeWrapper" do
      expect(TestTrack.analytics.class).to eq TestTrack::Analytics::SafeWrapper
      expect(TestTrack.analytics.underlying.class).to eq TestTrack::Analytics::MixpanelClient
    end

    it "wraps custom client in SafeWrapper" do
      begin
        default_client = TestTrack.analytics
        fake_client = double
        TestTrack.analytics = fake_client

        expect(TestTrack.analytics.class).to eq TestTrack::Analytics::SafeWrapper
        expect(TestTrack.analytics.underlying).to eq fake_client
      ensure
        TestTrack.analytics = default_client
      end
    end
  end

  describe "misconfguration_notifier" do
    it "wraps a custom notifier in Wrapper" do
      begin
        default_notifier = TestTrack.misconfiguration_notifier
        fake_notifier = double
        TestTrack.misconfiguration_notifier = fake_notifier
        expect(TestTrack.misconfiguration_notifier.class).to eq TestTrack::MisconfigurationNotifier::Wrapper
        expect(TestTrack.misconfiguration_notifier.underlying).to eq fake_notifier
      ensure
        TestTrack.misconfiguration_notifier = default_notifier
      end
    end

    it "defaults to null notifier" do
      expect(TestTrack.misconfiguration_notifier.class).to eq TestTrack::MisconfigurationNotifier::Wrapper
      expect(TestTrack.misconfiguration_notifier.underlying.class).to eq TestTrack::MisconfigurationNotifier::Null
    end

    context "when Airbrake is defined" do
      it "defaults Airbrake notifier" do
        begin
          default_notifier = TestTrack.misconfiguration_notifier
          stub_const("Airbrake", double("Airbrake"))
          if TestTrack.instance_variable_defined?(:@misconfiguration_notifier)
            TestTrack.remove_instance_variable(:@misconfiguration_notifier)
          end
          expect(TestTrack.misconfiguration_notifier.underlying.class).to eq TestTrack::MisconfigurationNotifier::Airbrake
        ensure
          TestTrack.misconfiguration_notifier = default_notifier
        end
      end
    end
  end

  describe ".app_ab" do
    around do |example|
      original_app_name = TestTrack.instance_variable_get("@app_name")
      example.run
      TestTrack.app_name = original_app_name
    end

    context "when app_name is specified" do
      before { TestTrack.app_name = 'test_track_spec' }

      context "when the ApplicationIdentity is assigned to the feature" do
        before do
          stub_test_track_assignments(dummy_feature: 'true')
        end
        it "returns true" do
          expect(TestTrack.app_ab(:dummy_feature, context: 'test_context')).to eq true
        end
      end

      context "when the ApplicationIdentity is not assigned to the feature" do
        before do
          stub_test_track_assignments(dummy_feature: 'false')
        end

        it "returns false" do
          expect(TestTrack.app_ab(:dummy_feature, context: 'test_context')).to eq false
        end
      end
    end

    context "when app_name is not specified" do
      before do
        TestTrack.app_name = nil
      end

      it "raises an error" do
        expect { TestTrack.app_ab(:dummy_feature, context: 'test_context') }
          .to raise_error("must configure TestTrack.app_name on application initialization")
      end
    end
  end
end
