require 'spec_helper'

module Spree
  describe Gateway::AdyenHPP do

    context "payment state inquiry/actions" do

      let(:captured_payment){ double('Payment', pending?: false, checkout?: false, void?: false, complete?: true) }
      let(:auth_payment){ double('Payment', pending?: false, checkout?: true, void?: false, complete?: false) }
      let(:voided_payment){ double('Payment', pending?: false, checkout?: false, void?: true, complete?: false) }
      let(:pending_payment){ double('Payment', pending?: true, checkout?: false, void?: false, complete?: false) }

      describe "#can_capture?" do

        it "prevents a capture unless the order's payment is either pending or checkout", external: true do

          aggregate_failures "capture responses" do
            expect(subject.can_capture?(auth_payment)).to eq(true)
            expect(subject.can_capture?(captured_payment)).to eq(false)
            expect(subject.can_capture?(voided_payment)).to eq(false)
            expect(subject.can_capture?(pending_payment)).to eq(true)
          end
        end
      end

      describe "#can_void?" do

        it "prevents a void unless the order's payment has not been captured or is not already voided ", external: true do

          aggregate_failures "void_responses" do
            expect(subject.can_void?(auth_payment)).to eq(true)
            expect(subject.can_void?(captured_payment)).to eq(false)
            expect(subject.can_void?(voided_payment)).to eq(false)
            expect(subject.can_void?(pending_payment)).to eq(true)
          end
        end
      end

      describe "#authorize" do
        let(:amount){ 200 }
        let(:source){ double("Source", foo: "bar") }
        let(:gateway_options){ {} }

        it "raises an HPPRedirectError", external: true do
          expect{ subject.authorize(amount, source, gateway_options) }.to raise_error(Spree::Adyen::HPPRedirectError)
        end

      end
    end

    context "comply with spree payment/processing api" do
      context "void" do
        it "makes response.authorization returns the psp reference", external: true do
          response = double('Response', success?: true, psp_reference: "huhu")
          allow(subject).to receive_message_chain(:provider, cancel_payment: response)
          expect(subject.void("huhu").authorization).to be_nil
        end
      end

      context "capture" do


        it "makes response.authorization returns nil", external: true do
          response = double('Response', success?: true, psp_reference: "huhu")
          allow(subject).to receive_message_chain(:provider, capture_payment: response)

          result = subject.capture(30000, "huhu")
          expect(result.authorization).to be_nil
          expect(result.avs_result).to eq({})
          expect(result.cvv_result).to eq({})
        end
      end
    end
  end
end
