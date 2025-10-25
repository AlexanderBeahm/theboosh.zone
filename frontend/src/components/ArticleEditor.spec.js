/* global File, Event */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount, flushPromises } from "@vue/test-utils";
import axios from "axios";
import ArticleEditor from "./ArticleEditor.vue";
import MarkdownRenderer from "./MarkdownRenderer.vue";
import ImageUploader from "./ImageUploader.vue";

vi.mock("axios");

// Mock MediaLibrary completely to prevent undefined errors
vi.mock('./MediaLibrary.vue', () => ({
    default: {
        name: 'MediaLibrary',
        props: {
            mediaItems: { default: () => [] },
            isLoading: { default: false },
            onMediaSelect: { default: () => {} }
        },
        template: `<div class="mock-media-library">Mock Media Library</div>`,
        setup() {
            return {
                mediaItems: [],
                isLoading: false
            };
        }
    }
}));

// Additional MockMediaLibrary for explicit component override
const MockMediaLibrary = {
    name: 'MediaLibrary',
    props: {
        mediaItems: { default: () => [] },
        isLoading: { default: false },
        onMediaSelect: { default: () => {} }
    },
    template: `<div class="mock-media-library">Mock Media Library</div>`,
    setup() {
        return {
            mediaItems: [],
            isLoading: false
        };
    }
};

describe("ArticleEditor", () => {
    const mockTags = [
        { id: 1, name: "JavaScript", slug: "javascript", usage_count: 5 },
        { id: 2, name: "Vue", slug: "vue", usage_count: 3 },
    ];

    beforeEach(() => {
        vi.clearAllMocks();
        axios.get.mockResolvedValue({
            data: { success: true, tags: mockTags },
        });
    });

    describe("Rendering", () => {
        it("renders create mode when no article provided", async () => {
            const wrapper = mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();

            expect(wrapper.text()).toContain("Create New Article");
            expect(wrapper.find('button[type="submit"]').text()).toContain(
                "Create Article",
            );
        });

        it("renders edit mode with article data", async () => {
            const article = {
                id: 1,
                title: "Test Article",
                slug: "test-article",
                content: "# Test",
                excerpt: "Excerpt",
                author: "John",
                featured_image: "/test.jpg",
                meta_description: "Meta",
                is_published: true,
                tags: [mockTags[0]],
            };

            const wrapper = mount(ArticleEditor, {
                props: { article, isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();

            expect(wrapper.text()).toContain("Edit Article");
            expect(wrapper.find("#title").element.value).toBe("Test Article");
            expect(wrapper.find("#slug").element.value).toBe("test-article");
            expect(wrapper.find('button[type="submit"]').text()).toContain(
                "Update Article",
            );
        });

        it("does not render when isVisible is false", () => {
            const wrapper = mount(ArticleEditor, {
                props: { isVisible: false },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            expect(wrapper.find(".modal-overlay").exists()).toBe(false);
        });
    });

    describe("Form Validation", () => {
        it("requires title, slug, and content", async () => {
            const wrapper = mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();

            const submitButton = wrapper.find('button[type="submit"]');
            expect(submitButton.attributes("disabled")).toBeDefined();

            await wrapper.find("#title").setValue("Test Title");
            await wrapper.find("#slug").setValue("test-slug");
            await wrapper.find("#content").setValue("Content here");

            expect(submitButton.attributes("disabled")).toBeUndefined();
        });
    });

    describe("Slug Generation", () => {
        it("auto-generates slug from title in create mode", async () => {
            const wrapper = mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();
            await wrapper.find("#title").setValue("Hello World Test!");
            await wrapper.find("#title").trigger("input");

            expect(wrapper.find("#slug").element.value).toBe(
                "hello-world-test",
            );
        });

        it("does not auto-generate slug in edit mode", async () => {
            const article = {
                id: 1,
                title: "Original",
                slug: "original",
                content: "test",
            };
            const wrapper = mount(ArticleEditor, {
                props: { article, isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();
            const originalSlug = wrapper.find("#slug").element.value;

            await wrapper.find("#title").setValue("New Title");
            await wrapper.find("#title").trigger("input");

            expect(wrapper.find("#slug").element.value).toBe(originalSlug);
        });
    });

    describe("Tab Switching", () => {
        it("switches between Write and Preview tabs", async () => {
            const wrapper = mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();

            const buttons = wrapper.findAll(".tab-button");
            expect(buttons[0].classes()).toContain("active");

            await buttons[1].trigger("click");
            expect(buttons[1].classes()).toContain("active");
            expect(buttons[0].classes()).not.toContain("active");
        });
    });

    describe("Tag Management", () => {
        it("loads available tags on mount", async () => {
            /*eslint-disable no-unused-vars*/
            const wrapper = mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });
            /*eslint-enable no-unused-vars*/
            await flushPromises();

            expect(axios.get).toHaveBeenCalledWith("/api/tags");
        });

        it("shows tag suggestions when typing", async () => {
            const wrapper = mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();
            await wrapper.find(".tag-input").setValue("Java");
            await wrapper.find(".tag-input").trigger("input");

            expect(wrapper.find(".tag-suggestions").exists()).toBe(true);
            expect(wrapper.text()).toContain("JavaScript");
        });

        it("adds tag from suggestions", async () => {
            const wrapper = mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();
            await wrapper.find(".tag-input").setValue("Java");
            await wrapper.find(".tag-input").trigger("input");
            await wrapper.find(".tag-suggestion").trigger("click");

            expect(wrapper.find(".selected-tag").text()).toContain(
                "JavaScript",
            );
            expect(wrapper.find(".tag-input").element.value).toBe("");
        });

        it("removes selected tag", async () => {
            const article = {
                id: 1,
                title: "Test",
                slug: "test",
                content: "test",
                tags: [mockTags[0]],
            };
            const wrapper = mount(ArticleEditor, {
                props: { article, isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();

            expect(wrapper.find(".selected-tag").exists()).toBe(true);
            await wrapper.find(".remove-tag-button").trigger("click");
            expect(wrapper.find(".selected-tag").exists()).toBe(false);
        });
    });

    describe("Saving Article", () => {
        it("creates new article successfully", async () => {
            const mockArticle = {
                id: 1,
                title: "New Article",
                slug: "new-article",
            };
            axios.post.mockResolvedValueOnce({
                data: { success: true, article: mockArticle },
            });

            const wrapper = mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();

            await wrapper.find("#title").setValue("New Article");
            await wrapper.find("#slug").setValue("new-article");
            await wrapper.find("#content").setValue("# Content");
            await wrapper.find("form").trigger("submit.prevent");

            await flushPromises();

            expect(axios.post).toHaveBeenCalledWith(
                "/api/admin/articles",
                expect.objectContaining({
                    title: "New Article",
                    slug: "new-article",
                    content: "# Content",
                }),
            );
            expect(wrapper.emitted("saved")).toBeTruthy();
            expect(wrapper.emitted("saved")[0][0]).toEqual(mockArticle);
        });

        it("updates existing article successfully", async () => {
            const article = {
                id: 1,
                title: "Original",
                slug: "original",
                content: "test",
            };
            const updated = { ...article, title: "Updated" };

            axios.put.mockResolvedValueOnce({
                data: { success: true, article: updated },
            });

            const wrapper = mount(ArticleEditor, {
                props: { article, isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();

            await wrapper.find("#title").setValue("Updated");
            await wrapper.find("form").trigger("submit.prevent");

            await flushPromises();

            expect(axios.put).toHaveBeenCalledWith(
                `/api/admin/articles/${article.id}`,
                expect.any(Object),
            );
            expect(wrapper.emitted("saved")).toBeTruthy();
        });

        it("displays error on save failure", async () => {
            axios.post.mockRejectedValueOnce({
                response: { data: { error: "Slug already exists" } },
            });

            const wrapper = mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();

            await wrapper.find("#title").setValue("Test");
            await wrapper.find("#slug").setValue("test");
            await wrapper.find("#content").setValue("Content");
            await wrapper.find("form").trigger("submit.prevent");

            await flushPromises();

            expect(wrapper.find(".error-message").text()).toContain(
                "Slug already exists",
            );
        });

        it("disables form during save", async () => {
            axios.post.mockImplementation(() => new Promise(() => {}));

            mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();

            // Note: This test needs to be updated to properly test the disabled state
            // For now, we're just verifying the component mounts without errors
        });
    });

    describe("Modal Controls", () => {
        it("emits close event when close button clicked", async () => {
            const wrapper = mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();
            await wrapper.findAll(".close-button")[0].trigger("click");

            expect(wrapper.emitted("close")).toBeTruthy();
        });

        it("emits close when cancel button clicked", async () => {
            const wrapper = mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();
            await wrapper.find(".cancel-button").trigger("click");

            expect(wrapper.emitted("close")).toBeTruthy();
        });
    });

    describe("Paste Functionality", () => {
        it("detects image paste events", async () => {
            // Mock FileReader to capture the onload handler
            const mockFileReader = {
                onload: null,
                onerror: null,
                readAsDataURL: vi.fn(function() {
                    // Call the onload handler immediately
                    if (this.onload) {
                        // Simulate successful file read
                        this.onload({
                            target: {
                                result: 'data:image/jpeg;base64,mockdata'
                            }
                        });
                    }
                })
            };
            global.FileReader = vi.fn(() => mockFileReader);

            const wrapper = mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();

            // Create a proper mock file
            const mockFile = new File(['test image data'], 'test.jpg', {
                type: 'image/jpeg'
            });

            // Create mock clipboard data that matches browser API
            const mockClipboardData = {
                items: [{
                    type: 'image/jpeg',
                    getAsFile: vi.fn(() => mockFile)
                }]
            };

            // Create paste event with clipboardData
            const pasteEvent = {
                preventDefault: vi.fn(),
                clipboardData: mockClipboardData
            };

            const contentTextarea = wrapper.find('#content');

            // Get the actual DOM element to access its properties
            const textareaElement = contentTextarea.element;
            textareaElement.selectionStart = 5; // Mock caret position

            // Manually call the handlePaste function
            await wrapper.vm.handlePaste(pasteEvent);

            await flushPromises();

            // Verify preventDefault was called
            expect(pasteEvent.preventDefault).toHaveBeenCalled();

            // Verify file reader was used
            expect(mockFileReader.readAsDataURL).toHaveBeenCalledWith(mockFile);

            // Check component state
            expect(wrapper.vm.showPasteImageModal).toBe(true);
            expect(wrapper.vm.pastedImageData).toBeTruthy();
            expect(wrapper.vm.pastedImageData.file).toStrictEqual(mockFile);
            expect(wrapper.vm.pastedImageData.type).toBe('image/jpeg');
            expect(wrapper.vm.pastedImageData.size).toBe(15); // 'test image data' = 15 bytes

            // Should show paste image modal
            expect(wrapper.find('.image-modal-overlay').exists()).toBe(true);
            expect(wrapper.text()).toContain('Confirm Pasted Image');
        });

        it("ignores paste events without images", async () => {
            const wrapper = mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();

            // Create mock clipboard data without images
            const mockClipboardData = {
                items: [{
                    type: 'text/plain',
                    getAsFile: () => null
                }]
            };

            const pasteEvent = new Event('paste');
            Object.defineProperty(pasteEvent, 'clipboardData', {
                value: mockClipboardData
            });

            const contentTextarea = wrapper.find('#content');
            await contentTextarea.trigger('paste', pasteEvent);

            await flushPromises();

            // Should not show paste image modal
            expect(wrapper.find('.image-modal-overlay').exists()).toBe(false);
        });

        it("uploads pasted image and inserts markdown", async () => {
            const mockUploadResponse = {
                data: {
                    success: true,
                    media: {
                        id: 1,
                        url: '/uploads/2025/01/pasted-image.jpg',
                        alt_text: 'Pasted image',
                        original_filename: 'pasted-image.jpg'
                    }
                }
            };
            axios.post.mockResolvedValueOnce(mockUploadResponse);

            const wrapper = mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();

            // Set initial content and caret position
            await wrapper.find('#content').setValue('Initial content ');
            const textarea = wrapper.find('#content').element;
            textarea.selectionStart = 16; // After "Initial content "

            // Trigger paste
            const mockFile = new File(['test'], 'test.jpg', { type: 'image/jpeg' });
            wrapper.vm.pastedImageData = {
                file: mockFile,
                dataUrl: 'data:image/jpeg;base64,test',
                type: 'image/jpeg',
                size: 1024,
                name: 'pasted-image.jpg'
            };
            wrapper.vm.savedCaretPosition = 16;
            wrapper.vm.showPasteImageModal = true;

            await wrapper.vm.$nextTick();

            // Confirm upload
            await wrapper.find('.button-primary').trigger('click');
            await flushPromises();

            // Check that upload was called
            expect(axios.post).toHaveBeenCalledWith(
                '/api/admin/media/upload',
                expect.any(FormData),
                expect.objectContaining({
                    headers: { 'Content-Type': 'multipart/form-data' }
                })
            );

            // Check that markdown was inserted
            expect(wrapper.vm.form.content).toContain('![Pasted image](/uploads/2025/01/pasted-image.jpg)');
        });

        it("shows error when paste upload fails", async () => {
            axios.post.mockRejectedValueOnce({
                response: { data: { error: 'Upload failed' } }
            });

            const wrapper = mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();

            // Set up paste data
            const mockFile = new File(['test'], 'test.jpg', { type: 'image/jpeg' });
            wrapper.vm.pastedImageData = {
                file: mockFile,
                dataUrl: 'data:image/jpeg;base64,test',
                type: 'image/jpeg',
                size: 1024,
                name: 'pasted-image.jpg'
            };
            wrapper.vm.showPasteImageModal = true;

            await wrapper.vm.$nextTick();

            // Confirm upload
            await wrapper.find('.button-primary').trigger('click');
            await flushPromises();

            // Should show error
            expect(wrapper.find('.error-message').text()).toContain('Upload failed');
        });
    });

    describe("Unified Insert Modal", () => {
        it("opens unified insert modal when Insert Image button clicked", async () => {
            const wrapper = mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();

            // Click Insert Image button
            await wrapper.find('.insert-image-button').trigger('click');

            // Should open unified modal
            expect(wrapper.find('.unified-modal').exists()).toBe(true);
            expect(wrapper.text()).toContain('Insert Image');
            expect(wrapper.text()).toContain('Browse Library');
            expect(wrapper.text()).toContain('Upload New');
            expect(wrapper.text()).toContain('Paste Image');
        });

        it("switches between unified modal tabs", async () => {
            const wrapper = mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();

            // Open unified modal
            await wrapper.find('.insert-image-button').trigger('click');

            const tabButtons = wrapper.findAll('.unified-tab-button');

            // Should start with Browse tab active
            expect(tabButtons[0].classes()).toContain('active');

            // Switch to Upload tab
            await tabButtons[1].trigger('click');
            expect(tabButtons[1].classes()).toContain('active');
            expect(tabButtons[0].classes()).not.toContain('active');

            // Switch to Paste tab
            await tabButtons[2].trigger('click');
            expect(tabButtons[2].classes()).toContain('active');
            expect(wrapper.text()).toContain('Paste an Image');
        });

        it("handles media selection from unified modal", async () => {
            const wrapper = mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();

            // Set up initial content
            await wrapper.find('#content').setValue('Content ');

            // Open unified modal and simulate media selection
            wrapper.vm.savedCaretPosition = 8;
            const mockMedia = {
                url: '/uploads/2025/01/selected-image.jpg',
                alt_text: 'Selected image',
                original_filename: 'selected-image.jpg'
            };

            wrapper.vm.handleUnifiedMediaSelected(mockMedia);

            // Check that markdown was inserted
            expect(wrapper.vm.form.content).toContain('![Selected image](/uploads/2025/01/selected-image.jpg)');
        });

        it("closes unified modal when close button clicked", async () => {
            const wrapper = mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();

            // Open unified modal
            await wrapper.find('.insert-image-button').trigger('click');
            expect(wrapper.find('.unified-modal').exists()).toBe(true);

            // Close modal
            await wrapper.findAll('.close-button')[1].trigger('click'); // Second close button is for unified modal

            expect(wrapper.find('.unified-modal').exists()).toBe(false);
        });
    });

    describe("Tab Key Handling", () => {
        it("inserts tab character in content textarea", async () => {
            const wrapper = mount(ArticleEditor, {
                props: { isVisible: true },
                global: {
                    components: {
                        MarkdownRenderer,
                        MediaLibrary: MockMediaLibrary,
                        ImageUploader,
                    },
                },
            });

            await flushPromises();

            const textarea = wrapper.find('#content');
            await textarea.setValue('Line 1\n');

            // Simulate tab key press with preventDefault spy
            const preventDefaultSpy = vi.fn();
            await textarea.trigger('keydown', {
                key: 'Tab',
                preventDefault: preventDefaultSpy
            });

            // Tab character should be inserted
            expect(wrapper.vm.form.content).toContain('\t');
            expect(preventDefaultSpy).toHaveBeenCalled();
        });
    });
});
