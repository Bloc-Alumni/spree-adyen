require 'spec_helper'

module Spree
  describe Gateway::AdyenHPP do
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
