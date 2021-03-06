# frozen_string_literal: true

require 'rails_helper'

describe Monarchy::Member, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:hierarchy) }
  it { is_expected.to have_many(:roles).through(:members_roles) }
  it { is_expected.to have_many(:members_roles).dependent(:destroy) }

  it { is_expected.to validate_presence_of(:user) }
  it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(:hierarchy_id) }

  describe 'validate resource or hierarchy' do
    let!(:user) { create(:user) }

    context 'valdiate resource' do
      context 'is present' do
        let!(:resource) { create(:project) }
        subject { Member.create(user: user, resource: resource) }

        it { expect(subject.valid?).to be true }
      end

      context 'is not present' do
        subject { Member.create(user: user) }

        it { expect(subject.valid?).to be false }
      end
    end

    context 'valdiate hierarchy' do
      context 'is present' do
        let!(:hierarchy) { create(:hierarchy) }
        subject { Member.create(user: user, hierarchy: hierarchy) }

        it { expect(subject.valid?).to be true }
      end

      context 'is not present' do
        subject { Member.create(user: user) }

        it { expect(subject.valid?).to be false }
      end
    end

    context 'valdiate hierarchy and resource' do
      context 'is present' do
        let!(:resource) { create(:project) }
        let!(:hierarchy) { create(:hierarchy) }
        subject { Member.create(user: user, hierarchy: hierarchy, resource: resource) }

        it { expect(subject.valid?).to be true }
        it { expect(subject.hierarchy).to eq(hierarchy) }
      end
    end
  end

  describe 'after destroy' do
    context 'revoke access' do
      let!(:guest_role) { create(:role, name: :guest, level: 0, inherited: false) }
      let!(:member_role) { create(:role, name: :member, level: 1, inherited: false) }

      let!(:user) { create :user }

      let!(:project) { create(:project) }
      let!(:memo) { create(:memo, parent: project) }
      let!(:memo2) { create(:memo, parent: memo) }
      let!(:memo3) { create(:memo, parent: memo2) }

      let!(:memo_member) { user.grant(:member, memo) }

      before do
        user.grant(:member, project)
        user.grant(:member, memo2)
        user.grant(:member, memo3)
      end

      subject { memo_member.destroy }

      it { is_expected_block.to change { Member.count }.to(1) }
      it { is_expected_block.to change { memo2.members.count }.to(0) }
      it { is_expected_block.to change { memo3.members.count }.to(0) }
    end
  end

  describe 'resource=' do
    let!(:project) { create :project }
    let!(:user) { create :user }
    let!(:member) { Member.create(user: user, resource: project) }

    subject { member.hierarchy }
    it { is_expected.to eq(member.resource.hierarchy) }
  end

  describe '.with_access_to' do
    let!(:project) { create :project }
    let!(:memo1) { create :memo, parent: project }
    let!(:memo2) { create :memo, parent: project }
    let!(:memo3) { create :memo, parent: memo2 }
    let!(:memo4) { create :memo, parent: memo3 }
    let!(:memo5) { create :memo, parent: memo2 }
    let!(:memo6) { create :memo, parent: memo3 }

    let!(:guest_role) { create(:role, name: :guest, level: 0, inherited: false) }
    let!(:member_role) { create(:role, name: :member, level: 1, inherited: true, inherited_role: guest_role) }
    let!(:manager_role) { create(:role, name: :manager, level: 2, inherited: true, inherited_role: owner_role) }
    let!(:owner_role) { create(:role, name: :owner, level: 3, inherited: true) }

    let!(:member1) { create(:user).grant(:owner, project) }
    let!(:member2) { create(:user).grant(:manager, memo2) }
    let!(:member3) { create(:user).grant(:guest, memo6) }
    let!(:member4) { create(:user).grant(:member, memo3) }
    let!(:member5) { create(:user).grant(:member, memo1) }
    let!(:member6) { create(:user).grant(:guest, memo1) }

    subject { Member.with_access_to(memo3) }

    it { expect { subject.to_a }.to make_database_queries(count: 1) }
    it { is_expected.to match_array([member1, member2, member3, member4]) }

    context 'resource is not a monarchy resource' do
      subject { Member.with_access_to(member1) }
      it { is_expected_block.to raise_exception(Monarchy::Exceptions::ModelNotResource) }
    end
  end

  describe '.accessible_for' do
    let!(:project) { create :project }
    let!(:memo1) { create :memo, parent: project }
    let!(:memo2) { create :memo, parent: project }
    let!(:memo3) { create :memo, parent: memo2 }
    let!(:memo4) { create :memo, parent: memo3 }
    let!(:memo5) { create :memo, parent: memo2 }
    let!(:memo6) { create :memo, parent: memo3 }

    let!(:manager_role) { create(:role, name: :manager, level: 2, inherited: true) }

    let!(:member2) { create :member, resource: memo1 }
    let!(:member3) { create :member, resource: memo5 }
    let!(:member4) { create :member, resource: memo6 }

    subject { Member.accessible_for(member.user) }

    context 'when user is not monarchy user' do
      subject { Member.accessible_for(member2) }

      it { is_expected_block.to raise_exception(Monarchy::Exceptions::ModelNotUser) }
    end

    context 'when user is nil' do
      subject { Member.accessible_for(nil) }

      it { is_expected_block.to raise_exception(Monarchy::Exceptions::UserIsNil) }
    end

    context 'user has access to all members if has manager role on root' do
      let!(:member) { create :member, resource: project, roles: [manager_role] }

      it { is_expected.to match_array([member, member2, member3, member4]) }
    end

    context 'user has access to only root members if has guest role on root' do
      let!(:member) { create :member, resource: project }

      it { is_expected.to match_array([member]) }
    end

    context 'user has access to memo3' do
      let!(:member) { create :member, resource: memo3, roles: [manager_role] }

      it { is_expected.to match_array([member, member4]) }
    end
  end
end
