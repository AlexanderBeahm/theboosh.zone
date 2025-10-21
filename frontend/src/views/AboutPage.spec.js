import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import AboutPage from "./AboutPage.vue";

describe("AboutPage", () => {
    it("renders the main heading", () => {
        const wrapper = mount(AboutPage);
        expect(wrapper.find("h1").text()).toBe("TheBoosh.Zone");
    });

    it("renders the author name section", () => {
        const wrapper = mount(AboutPage);
        const sections = wrapper.findAll("h2");
        expect(sections[0].text()).toBe("Alex Beahm");
    });

    it("displays GitHub link with correct attributes", () => {
        const wrapper = mount(AboutPage);
        const githubLink = wrapper.find(
            'a[href="https://github.com/AlexanderBeahm"]',
        );

        expect(githubLink.exists()).toBe(true);
        expect(githubLink.text()).toBe("GitHub");
        expect(githubLink.attributes("target")).toBe("_blank");
        expect(githubLink.attributes("rel")).toBe("noopener noreferrer");
    });

    it("displays LinkedIn link with correct attributes", () => {
        const wrapper = mount(AboutPage);
        const linkedinLink = wrapper.find(
            'a[href="https://www.linkedin.com/in/alex-beahm-5bb7a89b/"]',
        );

        expect(linkedinLink.exists()).toBe(true);
        expect(linkedinLink.text()).toBe("LinkedIn");
        expect(linkedinLink.attributes("target")).toBe("_blank");
        expect(linkedinLink.attributes("rel")).toBe("noopener noreferrer");
    });

    it("renders the Technology Stack section", () => {
        const wrapper = mount(AboutPage);
        const sections = wrapper.findAll("h2");
        expect(sections[1].text()).toBe("Technology Stack");
    });

    it("displays all technology stack items", () => {
        const wrapper = mount(AboutPage);
        const text = wrapper.text();

        expect(text).toContain("Perl with Mojolicious framework");
        expect(text).toContain("Vue 3 for frontend interactivity");
        expect(text).toContain("PostgreSQL for database");
        expect(text).toContain("Docker for containerization");
    });

    it("applies correct styling classes", () => {
        const wrapper = mount(AboutPage);
        expect(wrapper.find(".about-page").exists()).toBe(true);
        expect(wrapper.find(".about-content").exists()).toBe(true);
        expect(wrapper.find(".content").exists()).toBe(true);
    });

    it("has proper semantic structure with sections", () => {
        const wrapper = mount(AboutPage);
        const sections = wrapper.findAll("section");

        expect(sections.length).toBe(2);
        expect(sections[0].find("h2").text()).toBe("Alex Beahm");
        expect(sections[1].find("h2").text()).toBe("Technology Stack");
    });

    it("uses list elements for links and technologies", () => {
        const wrapper = mount(AboutPage);
        const lists = wrapper.findAll("ul");

        expect(lists.length).toBe(2);
        expect(lists[0].findAll("li").length).toBe(2); // GitHub and LinkedIn
        expect(lists[1].findAll("li").length).toBe(4); // 4 technology items
    });
});
