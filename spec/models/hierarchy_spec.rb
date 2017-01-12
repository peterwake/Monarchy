# frozen_string_literal: true
require 'rails_helper'

describe Monarchy::Hierarchy, type: :model do
  it { is_expected.to have_many(:members).dependent(:destroy) }
  it { is_expected.to belong_to(:resource) }

  it { is_expected.to validate_presence_of(:resource_id) }
  it { is_expected.to validate_presence_of(:resource_type) }

  describe '.in' do
    let(:project) { create :project }
    let!(:project2) { create :project, parent: project }
    let!(:memo1) { create :memo, parent: project }
    let!(:memo3) { create :memo, parent: project }

    subject { described_class.in(project.hierarchy) }

    context 'when model is not monarchy resource' do
      let!(:user) { create(:user) }

      it { expect { described_class.in(user) }.to raise_exception(Monarchy::Exceptions::ModelNotHierarchy) }
      it { expect { described_class.in(nil) }.to raise_exception(Monarchy::Exceptions::HierarchyIsNil) }
    end

    it do
      is_expected.to match_array([project2.status.hierarchy, project.status.hierarchy,
                                  memo1.hierarchy, project2.hierarchy, memo3.hierarchy])
    end

    context 'nested memo in memo' do
      let!(:memo3) { create :memo, parent: project2 }

      it do
        is_expected.to match_array([project2.status.hierarchy, project.status.hierarchy,
                                    memo1.hierarchy, project2.hierarchy, memo3.hierarchy])
      end
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

    let!(:user) { create :user }
    subject { described_class.accessible_for(user) }

    context 'when user is not monarchy user' do
      it { expect { described_class.accessible_for(project) }.to raise_exception(Monarchy::Exceptions::ModelNotUser) }
      it { expect { described_class.accessible_for(nil) }.to raise_exception(Monarchy::Exceptions::UserIsNil) }
    end

    context 'user has access to all parents memos and self' do
      let!(:guest_role) { create(:role, name: :guest, level: 0, inherited: false) }
      let!(:member_role) { create(:role, name: :member, level: 1, inherited: false, inherited_role: guest_role) }

      let!(:memo_member) { create(:member, user: user, hierarchy: memo4.hierarchy) }

      it { is_expected.to match_array([project.hierarchy, memo2.hierarchy, memo3.hierarchy, memo4.hierarchy]) }
      it { is_expected.not_to include(memo6.hierarchy, memo5.hierarchy, memo1.hierarchy) }

      context 'user has access to resources bellow' do
        let!(:manager_role) { create(:role, name: :manager, level: 1) }
        let!(:memo_member) { create(:member, user: user, hierarchy: memo3.hierarchy, roles: [manager_role, member_role]) }

        it do
          is_expected.to match_array([project.hierarchy, memo2.hierarchy,
                                      memo3.hierarchy, memo4.hierarchy, memo6.hierarchy])
        end
        it { is_expected.not_to include(memo5.hierarchy, memo1.hierarchy) }
      end

      context 'user has not access to resources bellow as guest' do
        let!(:memo_member) { create(:member, user: user, hierarchy: memo3.hierarchy, roles: [guest_role]) }

        it { is_expected.to match_array([project.hierarchy, memo2.hierarchy, memo3.hierarchy]) }
        it { is_expected.not_to include(memo5.hierarchy, memo1.hierarchy, memo4.hierarchy, memo6.hierarchy) }
      end

      context 'user has not access to resources bellow as member without roles' do
        let!(:memo_member) { create(:member, user: user, hierarchy: memo3.hierarchy, roles: []) }

        it { is_expected.to match_array([project.hierarchy, memo2.hierarchy, memo3.hierarchy]) }
        it { is_expected.not_to include(memo5.hierarchy, memo1.hierarchy, memo4.hierarchy, memo6.hierarchy) }
      end

      context 'user has not access to resources bellow as member' do
        context 'when user is member in memo3' do
          let!(:memo_member) { create(:member, user: user, hierarchy: memo3.hierarchy, roles: [member_role]) }

          it { is_expected.to match_array([project.hierarchy, memo2.hierarchy, memo3.hierarchy]) }
          it { is_expected.not_to include(memo5.hierarchy, memo1.hierarchy, memo4.hierarchy, memo6.hierarchy) }

          context 'when user has access to memo4 as visitor' do
            let!(:memo4_member) { create(:member, user: user, hierarchy: memo4.hierarchy) }

            it { is_expected.to match_array([project.hierarchy, memo2.hierarchy, memo3.hierarchy, memo4.hierarchy]) }
            it { is_expected.not_to include(memo5.hierarchy, memo1.hierarchy, memo6.hierarchy) }
          end

          context 'when user has access to memo4 as member' do
            let!(:memo4_member) { create(:member, user: user, hierarchy: memo4.hierarchy, roles: [member_role]) }

            it { is_expected.to match_array([project.hierarchy, memo2.hierarchy, memo3.hierarchy, memo4.hierarchy]) }
            it { is_expected.not_to include(memo5.hierarchy, memo1.hierarchy, memo6.hierarchy) }
          end
        end

        context 'when user is an owner in memo3' do
          let!(:owner_role) { create(:role, name: :owner, level: 3) }
          let!(:memo_member) { create(:member, user: user, hierarchy: memo2.hierarchy, roles: [member_role]) }
          let!(:memo3_member) { create(:member, user: user, hierarchy: memo3.hierarchy, roles: [owner_role]) }

          it do
            is_expected.to match_array([project.hierarchy, memo2.hierarchy, memo3.hierarchy,
                                        memo4.hierarchy, memo6.hierarchy])
          end
          it { is_expected.not_to include(memo5.hierarchy, memo1.hierarchy) }
        end
      end

      context 'user has access to resources bellow as manager' do
        let!(:owner_role) { create(:role, name: :owner, level: 3) }
        let!(:manager_role) { create(:role, name: :manager, level: 2, inherited_role: owner_role) }
        let!(:memo_member) { create(:member, user: user, hierarchy: memo3.hierarchy, roles: [manager_role]) }

        it do
          is_expected.to match_array([project.hierarchy, memo2.hierarchy,
                                      memo3.hierarchy, memo4.hierarchy, memo6.hierarchy])
        end

        it { is_expected.not_to include(memo5.hierarchy, memo1.hierarchy) }
      end
    end

    context '.accessible_for and .in' do
      context 'when have access to leaves' do
        let!(:owner_role) { create(:role, name: :owner, level: 3) }
        let!(:memo_member) { create(:member, user: user, hierarchy: project.hierarchy, roles: [owner_role]) }
        let(:hierarchy) { memo3.hierarchy }

        it { expect(described_class.accessible_for(user).in(hierarchy)).to match_array([memo6.hierarchy, memo4.hierarchy]) }
        it { expect(described_class.in(hierarchy).accessible_for(user)).to match_array([memo6.hierarchy, memo4.hierarchy]) }
      end

      context 'when have access to roots' do
        let!(:memo_member) { create(:member, user: user, hierarchy: memo4.hierarchy) }
        let(:hierarchy) { memo2.hierarchy }

        it { expect(described_class.accessible_for(user).in(hierarchy)).to match_array([memo3.hierarchy, memo4.hierarchy]) }
        it { expect(described_class.in(hierarchy).accessible_for(user)).to match_array([memo3.hierarchy, memo4.hierarchy]) }
      end
    end

    context 'with specified allowed roles' do
      context 'when only member role is allowed' do
        let!(:owner_role) { create(:role, name: :owner, level: 3) }
        let!(:member_role) { create(:role, name: :member, level: 1, inherited: false) }
        let!(:no_access_role) { create(:role, name: :blocked, level: 1, inherited: false) }
        let!(:memo7) { create :memo, parent: memo6 }

        subject { described_class.accessible_for(user, inherited_roles: [:member]) }

        context 'user has a member role in project' do
          before { user.grant(:member, memo3) }
          it do
            is_expected.to match_array([project.hierarchy, memo2.hierarchy,
                                        memo3.hierarchy, memo4.hierarchy, memo6.hierarchy,
                                        memo7.hierarchy])
          end
        end

        context 'user has a inherited role' do
          before { user.grant(:owner, memo3) }
          it do
            is_expected.to match_array([project.hierarchy, memo2.hierarchy,
                                        memo3.hierarchy, memo4.hierarchy, memo6.hierarchy,
                                        memo7.hierarchy])
          end
        end

        context 'user has other role without inheritance' do
          before { user.grant(:blocked, memo3) }
          it { is_expected.to match_array([memo3.hierarchy, memo2.hierarchy, project.hierarchy]) }
        end
      end
    end

    context 'with parent role access' do
      let!(:member_role) { create(:role, name: :member, level: 1, inherited: false) }

      before { user.grant(:member, memo5) }
      subject { described_class.accessible_for(user, parent_access: true) }

      it do
        is_expected.to match_array([project.hierarchy, project.status.hierarchy, memo2.hierarchy,
                                    memo1.hierarchy, memo5.hierarchy, memo3.hierarchy])
      end
    end
  end
end
